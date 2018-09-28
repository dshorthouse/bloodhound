# Apache Spark Bulk Import Data and Aggregations into MySQL

The following script written in Scala illustrates how to rapidly import into MySQL a massive GBIF occurrence csv file extracted from a Darwin Core Archive download like this one: [https://doi.org/10.15468/dl.gmhhju](https://doi.org/10.15468/dl.gmhhju). Other methods here produce aggregates of these same occurrence data for rapid import into relational tables. The goal here is to produce a unique list of agents as a union of recordedBy and identifiedBy Darwin Core fields while retaining their occurrence record memberships. This greatly accelerates processing and parsing steps prior to reconciling people names. Aggregating identifiedBy and recordedBy fields from an occurrence csv file containing 84M records takes 20-30 minutes using 6GB of memory.

- Create the database using the [schema in /db](db/bloodhound.sql)
- Ensure that MySQL has utf8mb4 collation. See [https://mathiasbynens.be/notes/mysql-utf8mb4](https://mathiasbynens.be/notes/mysql-utf8mb4) to set server connection
- Get the mysql-connector-java (Connector/J) from [https://dev.mysql.com/downloads/connector/j/8.0.html](https://dev.mysql.com/downloads/connector/j/8.0.html).

On a Mac with Homebrew:

```bash
$ brew install apache-spark
$ spark-shell --jars /usr/local/opt/mysql-connector-java/libexec/mysql-connector-java-8.0.12.jar --driver-memory 6G
```

```scala
import sys.process._
import org.apache.spark.sql.Column
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._

val sqlContext = new org.apache.spark.sql.SQLContext(sc)

//load a big tsv from a DwC-A
val df = spark.
    read.
    format("csv").
    option("inferSchema", "true").
    option("header", "true").
    option("mode", "DROPMALFORMED").
    option("delimiter", "\t").
    option("quote", "\"").
    option("escape", "\"").
    option("treatEmptyValuesAsNulls", "true").
    option("ignoreLeadingWhiteSpace", "true").
    load("/Users/dshorthouse/Downloads/GBIF Data/verbatim.txt")

df.registerTempTable("occurrences")

//select columns & skip rows if both identifiedBy and recordedBy are empty
val occurrences = sqlContext.
    sql("""
      SELECT 
        gbifID AS id,
        occurrenceID,
        dateIdentified,
        decimalLatitude,
        decimalLongitude,
        eventDate,
        family,
        identifiedBy,
        institutionCode,
        collectionCode,
        catalogNumber,
        recordedBy,
        scientificName,
        typeStatus 
      FROM 
        occurrences 
      WHERE 
        COALESCE(recordedBy, identifiedBy) IS NOT NULL""")

//optionally save the DataFrame to disk so we don't have to do the above again
occurrences.write.save("occurrences")

//load the saved DataFrame, can later skip the above processes and start from here
val occurrences = spark.
    read.
    option("header","true").
    load("occurrences")

//set some properties for a MySQL connection
val prop = new java.util.Properties
prop.setProperty("driver", "com.mysql.cj.jdbc.Driver")
prop.setProperty("user", "root")
prop.setProperty("password", "")

val url = "jdbc:mysql://localhost:3306/bloodhound?serverTimezone=UTC&useSSL=false"

//write occurrences data to the database
occurrences.write.mode("append").jdbc(url, "occurrences", prop)

//aggregate recordedBy
val recordedByGroups = occurrences.
    filter(!isnull($"recordedBy")).
    groupBy($"recordedBy" as "agents").
    agg(collect_set($"id") as "gbifIDs_recordedBy")

//aggregate identifiedBy
val identifiedByGroups = occurrences.
    filter(!isnull($"identifiedBy")).
    groupBy($"identifiedBy" as "agents").
    agg(collect_set($"id") as "gbifIDs_identifiedBy")

//union identifiedBy and recordedBy entries
val unioned = spark.
    read.
    json(recordedByGroups.toJSON.union(identifiedByGroups.toJSON))

//optionally save the DataFrame to disk
unioned.write.save("occurrences-unioned")

//load the saved DataFrame, can later skip all the above processes
val unioned = spark.
    read.
    option("header","true").
    load("occurrences-unioned")

//concatenate arrays into strings
def stringify(c: Column) = concat(lit("["), concat_ws(",", c), lit("]"))

//write aggregated agents to csv files for the Parse & Populate Agents script, /bin/parse_agents.rb
unioned.select("agents", "gbifIDs_recordedBy", "gbifIDs_identifiedBy").
    withColumn("gbifIDs_recordedBy", stringify($"gbifIDs_recordedBy")).
    withColumn("gbifIDs_identifiedBy", stringify($"gbifIDs_identifiedBy")).
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("agents-unioned-csv")

//aggregate families (Taxa)
val familyGroups = occurrences.
    filter(!isnull($"family")).
    groupBy($"family").
    agg(collect_set($"id") as "gbifIDs_family")

//write aggregated families to csv files for the Populate Taxa script, /bin/populate_taxa.rb
familyGroups.select("family", "gbifIDs_family").
    withColumn("gbifIDs_family", stringify($"gbifIDs_family")).
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("family-csv")
