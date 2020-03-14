# Apache Spark Bulk Import Data and Aggregations into MySQL

The following script written in Scala illustrates how to rapidly import into MySQL a massive GBIF occurrence csv file extracted from a Darwin Core Archive download like this one: [https://doi.org/10.15468/dl.gyp78m](https://doi.org/10.15468/dl.gyp78m). Other methods here produce aggregates of these same occurrence data for rapid import into relational tables. The goal here is to produce a unique list of agents as a union of recordedBy and identifiedBy Darwin Core fields while retaining their occurrence record memberships. This greatly accelerates processing and parsing steps prior to storing graphs of people names in Neo4j. Aggregating identifiedBy and recordedBy fields from a raw occurrence csv file containing 190M records takes approx. 1 hr using 12GB of memory.

- Create the database using the [schema in /db](db/bloodhound.sql)
- Ensure that MySQL has utf8mb4 collation. See [https://mathiasbynens.be/notes/mysql-utf8mb4](https://mathiasbynens.be/notes/mysql-utf8mb4) to set server connection
- Get the mysql-connector-java (Connector/J) from [https://dev.mysql.com/downloads/connector/j/8.0.html](https://dev.mysql.com/downloads/connector/j/8.0.html).

On a Mac with Homebrew:

```bash
$ brew install apache-spark
$ spark-shell --jars /usr/local/opt/mysql-connector-java/libexec/mysql-connector-java-8.0.19.jar --driver-memory 12G
```

```scala
import sys.process._
import org.apache.spark.sql.Column
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._

val verbatimTerms = List(
  "gbifID",
  "occurrenceID",
  "dateIdentified",
  "decimalLatitude",
  "decimalLongitude",
  "country",
  "eventDate",
  "year",
  "family",
  "identifiedBy",
  "institutionCode",
  "collectionCode",
  "catalogNumber",
  "recordedBy",
  "scientificName",
  "typeStatus"
)

//load a big, verbatim tsv file from a DwC-A download
val df1 = spark.
    read.
    format("csv").
    option("header", "true").
    option("mode", "DROPMALFORMED").
    option("delimiter", "\t").
    option("quote", "\"").
    option("escape", "\"").
    option("treatEmptyValuesAsNulls", "true").
    option("ignoreLeadingWhiteSpace", "true").
    load("/Users/dshorthouse/Downloads/GBIF/verbatim.txt").
    select(verbatimTerms.map(col): _*).
    filter(coalesce($"identifiedBy",$"recordedBy").isNotNull).
    where(!$"scientificName".contains("BOLD:")).
    where(!$"scientificName".contains("BOLD-")).
    where(!$"scientificName".contains("BIOUG"))

//optionally save the DataFrame to disk so we don't have to do the above again
df1.write.mode("overwrite").parquet("verbatim")

//load the saved DataFrame, can later skip the above processes and start from here
val df1 = spark.
    read.
    parquet("verbatim")

val processedTerms = List(
  "gbifID",
  "datasetKey",
  "countryCode",
  "dateIdentified",
  "eventDate",
  "mediaType"
)

val df2 = spark.
    read.
    format("csv").
    option("header", "true").
    option("mode", "DROPMALFORMED").
    option("delimiter", "\t").
    option("quote", "\"").
    option("escape", "\"").
    option("treatEmptyValuesAsNulls", "true").
    option("ignoreLeadingWhiteSpace", "true").
    load("/Users/dshorthouse/Downloads/GBIF/occurrence.txt").
    select(processedTerms.map(col): _*).
    filter(coalesce($"datasetKey",$"countryCode",$"dateIdentified",$"eventDate",$"mediaType").isNotNull).
    withColumnRenamed("dateIdentified","dateIdentified_processed").
    withColumnRenamed("eventDate", "eventDate_processed").
    withColumnRenamed("mediaType", "hasImage").
    withColumn("eventDate_processed", to_timestamp($"eventDate_processed")).
    withColumn("dateIdentified_processed", to_timestamp($"dateIdentified_processed")).
    withColumn("hasImage", when($"hasImage".contains("StillImage"), 1).otherwise(0))

//optionally save the DataFrame to disk so we don't have to do the above again
df2.write.mode("overwrite").parquet("processed")

//df2.write.format("avro").save("processed.avro")

//load the saved DataFrame, can later skip the above processes and start from here
val df2 = spark.
    read.
    parquet("processed")

val occurrences = df1.join(df2, Seq("gbifID"), "leftouter").orderBy($"gbifID").distinct

//set some properties for a MySQL connection
val prop = new java.util.Properties
prop.setProperty("driver", "com.mysql.cj.jdbc.Driver")
prop.setProperty("user", "root")
prop.setProperty("password", "")

val url = "jdbc:mysql://localhost:3306/bloodhound?serverTimezone=UTC&useSSL=false"

// Best to drop indices then recreate later
// ALTER TABLE `occurrences` DROP KEY `typeStatus_idx`, DROP KEY `index_occurrences_on_datasetKey`;

//write occurrences data to the database
occurrences.write.mode("append").jdbc(url, "occurrences", prop)

// Recreate indices
// ALTER TABLE `occurrences` ADD KEY `typeStatus_idx` (`typeStatus`(256)), ADD KEY `index_occurrences_on_datasetKey` (`datasetKey`);

//aggregate recordedBy
val recordedByGroups = occurrences.
    filter($"recordedBy".isNotNull).
    groupBy($"recordedBy" as "agents").
    agg(collect_set($"gbifID") as "gbifIDs_recordedBy")

//aggregate identifiedBy
val identifiedByGroups = occurrences.
    filter($"identifiedBy".isNotNull).
    groupBy($"identifiedBy" as "agents").
    agg(collect_set($"gbifID") as "gbifIDs_identifiedBy")

//union identifiedBy and recordedBy entries
val unioned = spark.
    read.
    json(recordedByGroups.toJSON.union(identifiedByGroups.toJSON))

//concatenate arrays into strings
def stringify(c: Column) = concat(lit("["), concat_ws(",", c), lit("]"))

//write aggregated agents to csv files for the Populate Agents script, /bin/populate_agents.rb
unioned.select("agents", "gbifIDs_recordedBy", "gbifIDs_identifiedBy").
    withColumn("gbifIDs_recordedBy", stringify($"gbifIDs_recordedBy")).
    withColumn("gbifIDs_identifiedBy", stringify($"gbifIDs_identifiedBy")).
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("agents-unioned-csv")

// Best to drop indices then recreate later, after all jobs are complete
// ALTER TABLE `occurrence_determiners` DROP KEY `agent_idx`, DROP KEY `occurrence_idx`;
// ALTER TABLE `occurrence_recorders` DROP KEY `agent_idx`, DROP KEY `occurrence_idx`;

// Recreate indices
// ALTER TABLE `occurrence_determiners` ADD KEY `agent_idx` (`agent_id`), ADD KEY `occurrence_idx` (`occurrence_id`);
// ALTER TABLE `occurrence_recorders` ADD KEY `agent_idx` (`agent_id`), ADD KEY `occurrence_idx` (`occurrence_id`);

//aggregate families (Taxa)
val familyGroups = occurrences.
    filter($"family".isNotNull).
    groupBy($"family").
    agg(collect_set($"gbifID") as "gbifIDs_family")

//write aggregated Families to csv files for the Populate Taxa script, /bin/populate_taxa.rb
familyGroups.select("family", "gbifIDs_family").
    withColumn("gbifIDs_family", stringify($"gbifIDs_family")).
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("family-csv")
```
