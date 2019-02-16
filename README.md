# Bloodhound
Sinatra app to parse people names from structured biodiversity occurrence data, apply basic regular expressions and heuristics to disambiguate them, and then allow them to be claimed by authenticated users via [ORCID](https://orcid.org). Authenticated users may also help other users that have either ORCID or Wikidata identifiers.

[![Build Status](https://travis-ci.org/dshorthouse/bloodhound.svg?branch=master)](https://travis-ci.org/dshorthouse/bloodhound)

## Recent Updates

- **February 15, 2019**: Use Wikidata as optional identifier for the deceased.
- **February 3, 2019**: Allow download of candidate specimen records then upload of claims.
- **January 26, 2019**: Present citations of user specimens based on contents of GBIF data packages.
- **October 12, 2018**: Used Neo4j to store weighted graphs of similarly structured people names as a quick mechanism to expand the list of users' candidate specimens & then present them in greatest to least probable.
- **September 29, 2018**: The core, parsing component of this project has been split off into a stand-alone ruby gem, [dwc_agent](https://rubygems.org/gems/dwc_agent).

## Requirements

1. ruby 2.5.1+
2. Elasticsearch 6.2.4+
3. MySQL 14.14+
4. Redis 4.0.9+
5. Apache Spark 2+
6. Neo4j
7. Unix-based operating system to use GNU parallel

## Installation

     $ git clone https://github.com/dshorthouse/bloodhound.git
     $ cd bloodhound
     $ gem install bundler
     $ bundle install
     $ mysql -u root bloodhound < db/bloodhound.sql
     $ cp config.yml.sample config.yml
     # Adjust content of config.yml
     $ rackup -p 4567 config.ru

## Steps to Import Data & Execute Parsing / Clustering

### Step 1:  Import Data

See the [Apache Spark recipes](spark.md) for quickly importing into MySQL the occurrence csv from a DwC Archive downloaded from [GBIF](https://www.gbif.org). Apache Spark is used to produce the necessary source csv files for the "Parse & Populate Agents" and "Populate Taxa" steps below.

### Step 2:  Parse & Populate Agents

     $ RACK_ENV=production ./bin/populate_agents.rb --truncate --directory /directory-to-spark-csv-files/
     $ RACK_ENV=production sidekiq -c 40 -q agent -r ./environment.rb

### Step 3: Populate Taxa

     $ RACK_ENV=production ./bin/populate_taxa.rb --truncate --directory /directory-to-spark-csv-files/
     $ RACK_ENV=production sidekiq -c 40 -q taxon -r ./environment.rb

Also execute SQL statement at end of [/bin/populate_taxa.rb script](bin/populate_taxa.rb) once queue is finished.

### Step 4: Cluster Agents & Store in Neo4j

     $ RACK_ENV=production ./bin/cluster_agents.rb --truncate --cluster
     $ RACK_ENV=production sidekiq -c 40 -q cluster -r ./environment.rb

Truncating a large Neo4j graph.db usually does not work. Instead, it is best to entirely delete the graph.db directory then recreate it.

Example on Mac with homebrew:

     $ brew services stop neo4j
     $ sudo rm -rf /usr/local/opt/neo4j/libexec/data/databases/graph.db
     $ brew services start neo4j # recreates graph.db
     $ rake neo4j:migrate # recreate the constraint on graph.db

### Step 5: Populate Search in Elasticsearch

     $ RACK_ENV=production ./bin/populate_search.rb --rebuild

## Neo4j Dump & Restore

Notes to self because I never remember how to dump from my laptop and reload onto the server. Must stop Neo4j before this can be executed.

      neo4j-admin dump --database=<database> --to=<destination-path>
      neo4j-admin load --from=<archive-path> --database=<database> [--force]

Example:

      brew services stop neo4j
      neo4j-admin dump --database=graph.db --to=/Users/dshorthouse/Documents/neo4j_backup/
      brew services start neo4j

      service neo4j stop
      rm -rf /var/lib/neo4j/data/databases/graph.db
      neo4j-admin load --from=/home/dshorthouse/neo4j_backup/graph.db.dump --database=graph.db
      #reset permissions
      chown neo4j:neo4j -R /var/lib/neo4j/data/databases/graph.db
      service neo4j start

Replacing the database through load requires that the database first be deleted [usually found in /var/lib/neo4j/data/databases on linux machine] and then its permissions be recursively set for the neo4j:adm user:group.

## Successive Data Migrations

Unfortunately, gbifIDs are not persistent. These occasionally disappear through processing at GBIF's end. As a result, claims may no longer point to an existing occurrence record and these must then be purged from the user_occurrences table. The following SQL statement can remove these with successive data imports from GBIF:

      DELETE uo FROM user_occurrences uo LEFT JOIN occurrences o ON uo.occurrence_id = o.gbifID WHERE o.gbifID IS NULL;

Other considerations are how to get MySQL dump files back on the server. For fastest execution, dump separate tables into each dump file.

      mysqlcheck -u root -o bloodhound
      mysqldump --user root --opt bloodhound agents | gzip > agents.sql.gz
      mysqldump --user root --opt bloodhound occurrences | gzip > occurrences.sql.gz
      etc...

Alternatively, mydumper and myloader can be used to accelerate these tasks.

      brew install mydumper
      mydumper --user root --database bloodhound --table-list agents,occurrence,occurrence_recorders,occurrence_determiners,taxa,taxon_occurrences,taxon_determiners --compress --no-schemas --threads 8 --outputdir /Users/dshorthouse/bloodhound_dump

      apt-get install mydumper
      myloader --database bloodhound --user bloodhound --password --threads 8 --directory /home/dshorthouse/bloodhound_restore

## License

The MIT License (MIT)

Copyright (c) David P. Shorthouse

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.