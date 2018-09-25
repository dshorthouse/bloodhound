# Apache Spark Bulk Import to MySQL

Important: Ensure that MySQL has utf8mb4 collation. See https://mathiasbynens.be/notes/mysql-utf8mb4 to set server, table, columns.

    $ spark-shell --jars /usr/local/opt/mysql-connector-java/libexec/mysql-connector-java-8.0.12.jar

    scala> val sqlContext = new org.apache.spark.sql.SQLContext(sc)
    scala> val df_csv = sqlContext.read.format("com.databricks.spark.csv").option("header", "true").option("delimiter", "\t").option("inferSchema", "true").load("/Users/dshorthouse/Downloads/GBIF Data/verbatim.txt")

    scala> df_csv.registerTempTable("occurrences")

    scala> val occurrences = sqlContext.sql("select gbifID AS id, occurrenceID, dateIdentified, decimalLatitude, decimalLongitude, eventDate, family, identifiedBy, institutionCode, collectionCode, catalogNumber, recordedBy, scientificName, typeStatus FROM occurrences WHERE COALESCE(recordedBy, identifiedBy) IS NOT NULL")

    scala> occurrences.printSchema

    scala> val prop = new java.util.Properties
    scala> prop.setProperty("driver", "com.mysql.cj.jdbc.Driver")
    scala> prop.setProperty("user", "root")
    scala> prop.setProperty("password", "")

    scala> val url = "jdbc:mysql://localhost:3306/bloodhound?serverTimezone=UTC&useSSL=false"

    scala> val table = "occurrences"
    scala> occurrences.write.mode("append").jdbc(url, table, prop)