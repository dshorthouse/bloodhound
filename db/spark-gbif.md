# Apache Spark Bulk Import to MySQL

- Ensure that MySQL has utf8mb4 collation. See [https://mathiasbynens.be/notes/mysql-utf8mb4](https://mathiasbynens.be/notes/mysql-utf8mb4) to set server, table, columns.
- Get the mysql-connector-java (Connector/J) from [https://dev.mysql.com/downloads/connector/j/8.0.html](https://dev.mysql.com/downloads/connector/j/8.0.html).

```bash
$ brew install apache-spark
$ spark-shell --jars /usr/local/opt/mysql-connector-java/libexec/mysql-connector-java-8.0.12.jar
```

```scala
val sqlContext = new org.apache.spark.sql.SQLContext(sc)
val df_csv = sqlContext.read.format("com.databricks.spark.csv").option("header", "true").option("delimiter", "\t").option("inferSchema", "true").load("/Users/dshorthouse/Downloads/GBIF Data/verbatim.txt")
df_csv.registerTempTable("occurrences")

val occurrences = sqlContext.sql("select gbifID AS id, occurrenceID, dateIdentified, decimalLatitude, decimalLongitude, eventDate, family, identifiedBy, institutionCode, collectionCode, catalogNumber, recordedBy, scientificName, typeStatus FROM occurrences WHERE COALESCE(recordedBy, identifiedBy) IS NOT NULL")

occurrences.printSchema

val prop = new java.util.Properties
prop.setProperty("driver", "com.mysql.cj.jdbc.Driver")
prop.setProperty("user", "root")
prop.setProperty("password", "")

val url = "jdbc:mysql://localhost:3306/bloodhound?serverTimezone=UTC&useSSL=false"
val table = "occurrences"

occurrences.write.mode("append").jdbc(url, table, prop)
```