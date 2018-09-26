# Apache Spark Bulk Import to MySQL

...and get unique, unparsed identifiedBy and recordedBy entries with gbifID associations

- Ensure that MySQL has utf8mb4 collation. See [https://mathiasbynens.be/notes/mysql-utf8mb4](https://mathiasbynens.be/notes/mysql-utf8mb4) to set server, table, columns.
- Get the mysql-connector-java (Connector/J) from [https://dev.mysql.com/downloads/connector/j/8.0.html](https://dev.mysql.com/downloads/connector/j/8.0.html).
- install the dwc\_agent gem:

`$ gem install dwc_agent`

```bash
$ brew install apache-spark
$ spark-shell --jars /usr/local/opt/mysql-connector-java/libexec/mysql-connector-java-8.0.12.jar
```

```scala
val sqlContext = new org.apache.spark.sql.SQLContext(sc)

val df = spark.read.format("csv").option("header", "true").option("mode", "DROPMALFORMED").option("delimiter", "\t").option("treatEmptyValuesAsNulls", "true").load("/Users/dshorthouse/Downloads/GBIF Data/verbatim.txt")

val occurrences = sqlContext.sql("select gbifID AS id, occurrenceID, dateIdentified, decimalLatitude, decimalLongitude, eventDate, family, identifiedBy, institutionCode, collectionCode, catalogNumber, recordedBy, scientificName, typeStatus FROM occurrences WHERE COALESCE(recordedBy, identifiedBy) IS NOT NULL")

//convert to parquet for better performance
occurrences.write.parquet("csv_to_parquet")

//once created, we can read it again from here without re-executing above steps
val occurrence_parquet = spark.read.option("header","true").parquet("csv_to_parquet")
occurrence_parquet.registerTempTable("occurrences")

val prop = new java.util.Properties
prop.setProperty("driver", "com.mysql.cj.jdbc.Driver")
prop.setProperty("user", "root")
prop.setProperty("password", "")

val url = "jdbc:mysql://localhost:3306/bloodhound?serverTimezone=UTC&useSSL=false"

//write occurrences data to the database
occurrence_parquet.write.mode("append").jdbc(url, "occurrences", prop)

//aggregate recordedBy
val recordedByGroups = occurrence_parquet.filter(!isnull($"recordedBy")).groupBy($"recordedBy" as "agents").agg(concat_ws(",", collect_set($"id")) as "recordedByIDs")

//aggregate identifiedBy
val identifiedByGroups = occurrence_parquet.filter(!isnull($"identifiedBy")).groupBy($"identifiedBy" as "agents").agg(concat_ws(",", collect_set($"id")) as "identifiedByIDs")

//union identifiedBy and recordedBy entries
val unioned = spark.read.json(recordedByGroups.toJSON.union(identifiedByGroups.toJSON))
unioned.coalesce(25).write.mode("overwrite").csv("rawAgentsActions")