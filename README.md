# Bloodhound
Sinatra app to parse people names from structured biodiversity occurrence data, apply basic regular expressions and heuristics to disambiguate them, and then allow them to be claimed by authenticated users via [ORCID](https://orcid.org). Authenticated users may also help other users that have either ORCID or Wikidata identifiers. The web application lives at [https://bloodhound-tracker.net](https://bloodhound-tracker.net).

[![Build Status](https://travis-ci.org/dshorthouse/bloodhound.svg?branch=master)](https://travis-ci.org/dshorthouse/bloodhound)

## Recent Updates

- **December 1, 2019**: Include datasets indexed by GBIF, each with pages for people and agents.
- **February 15, 2019**: Use Wikidata as optional identifier for the deceased.
- **February 3, 2019**: Allow download of candidate specimen records then upload of claims.
- **January 26, 2019**: Present citations of user specimens based on contents of GBIF data packages.
- **October 12, 2018**: Used Neo4j to store weighted graphs of similarly structured people names as a quick mechanism to expand the list of users' candidate specimens & then present them in greatest to least probable.
- **September 29, 2018**: The core, parsing component of this project has been split off into a stand-alone ruby gem, [dwc_agent](https://rubygems.org/gems/dwc_agent).

## Requirements

1. ruby 2.6.3+
2. Elasticsearch 6.2.4+
3. MySQL 14.14+
4. Redis 4.0.9+
5. Apache Spark 2+
6. Neo4j
7. Unix-based operating system to use GNU parallel to process GBIF downloads

## Installation

     $ git clone https://github.com/dshorthouse/bloodhound.git
     $ cd bloodhound
     $ gem install bundler
     $ bundle install
     $ mysql -u root bloodhound < db/bloodhound.sql
     $ cp config/settings/development.yml.sample config/settings/development.yml
     # Adjust content of development.yml
     # Copy and edit production.yml and test.yml as above
     $ rackup -p 4567 config.ru

## Steps to Import Data & Execute Parsing / Clustering

### Step 1:  Import Data

See the [Apache Spark recipes](spark.md) for quickly importing into MySQL the occurrence csv from a DwC Archive downloaded from [GBIF](https://www.gbif.org). Apache Spark is used to produce the necessary source csv files for the "Parse & Populate Agents" and "Populate Taxa" steps below.

### Step 2:  Parse & Populate Agents

     $ RACK_ENV=production ./bin/populate_agents.rb --truncate --directory /directory-to-spark-csv-files/
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     $ RACK_ENV=production sidekiq -c 40 -q agent -r ./application.rb

### Step 3: Populate Taxa

     $ RACK_ENV=production ./bin/populate_taxa.rb --truncate --directory /directory-to-spark-csv-files/
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     $ RACK_ENV=production sidekiq -c 40 -q taxon -r ./application.rb

### Step 4: Cluster Agents & Store in Neo4j

Truncating a large Neo4j graph.db usually does not work. Instead, it is best to entirely delete graph.db then recreate it.

Example on Mac with homebrew:

     $ brew services stop neo4j
     $ sudo rm -rf /usr/local/opt/neo4j/libexec/data/databases/graph.db
     # Could also be
     $ sudo rm -rf /usr/local/var/neo4j/data/databases/graph.db
     $ brew services start neo4j # recreates graph.db
     $ rake neo4j:migrate # recreate the constraint on graph.db

Finally:

     $ RACK_ENV=production ./bin/cluster_agents.rb --truncate --cluster
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     $ RACK_ENV=production sidekiq -c 40 -q cluster -r ./application.rb

### Step 5: Populate Search in Elasticsearch

     $ RACK_ENV=production ./bin/populate_search.rb --rebuild

### Step 6: Populate dataset metadata

     $ RACK_ENV=production ./bin/gbif_datasets.rb --new
     $ RACK_ENV=production ./bin/gbif_datasets.rb --flush
     $ RACK_ENV=production ./bin/gbif_datasets.rb --remove-without-agents

Or from scratch:

     $ RACK_ENV=production ./bin/gbif_datasets.rb --populate

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
      chown neo4j:adm -R /var/lib/neo4j/data/databases/graph.db
      service neo4j start

Replacing the database through load requires that the database first be deleted [usually found in /var/lib/neo4j/data/databases on linux machine] and then its permissions be recursively set for the neo4j:adm user:group.

## Successive Data Migrations

Unfortunately, gbifIDs are not persistent. These occasionally disappear through processing at GBIF's end. As a result, claims may no longer point to an existing occurrence record and these must then be purged from the user_occurrences table. The following SQL statement can remove these with successive data imports from GBIF:

      RACK_ENV=production irb
      require "./application"
      UserOccurrence.unlinked_count
      UserOccurrence.unlinked_delete

      ArticleOccurrence.unlinked_count
      ArticleOccurrence.unlinked_delete

To migrate tables, use mydumper and myloader. But for even faster data migration, best to drop indices before mydumper then recreate indices after myloader. This is especially true for the three largest tables: occurrences, occurrence_recorders, and occurrence_determiners.

      brew install mydumper

      ALTER TABLE `occurrences` DROP KEY `typeStatus_idx`, DROP KEY `index_occurrences_on_datasetKey`;
      ALTER TABLE `occurrence_determiners` DROP KEY `agent_idx`, DROP KEY `occurrence_idx`;
      ALTER TABLE `occurrence_recorders` DROP KEY `agent_idx`, DROP KEY `occurrence_idx`;
      ALTER TABLE `taxon_occurrences` DROP KEY `occurrence_id_idx`, DROP KEY `taxon_id_idx`;

      mydumper --user root --password <PASSWORD> --database bloodhound --tables-list agents,occurrences,occurrence_recorders,occurrence_determiners,taxa,taxon_occurrences --compress --threads 8 --rows 10000000 --trx-consistency-only --outputdir /Users/dshorthouse/Documents/bloodhound_dump

      apt-get install mydumper
      nohup myloader --database bloodhound_new --user bloodhound --password <PASSWORD> --threads 8 --queries-per-transaction 100 --compress-protocol --overwrite-tables --directory /home/dshorthouse/bloodhound_restore &

      ALTER TABLE `occurrences` ADD KEY `typeStatus_idx` (`typeStatus`(256)), ADD KEY `index_occurrences_on_datasetKey` (`datasetKey`);
      ALTER TABLE `occurrence_determiners` ADD KEY `agent_idx` (`agent_id`), ADD KEY `occurrence_idx` (`occurrence_id`);
      ALTER TABLE `occurrence_recorders` ADD KEY `agent_idx` (`agent_id`), ADD KEY `occurrence_idx` (`occurrence_id`);
      ALTER TABLE `taxon_occurrences` ADD UNIQUE KEY `occurrence_id_idx` (`occurrence_id`), ADD KEY `taxon_id_idx` (`taxon_id`);

Then, take site offline and in the bloodhound database DROP the tables with old data:

      DROP TABLE `agents`;
      DROP TABLE `occurrences`;
      DROP TABLE `occurrence_determiners`;
      DROP TABLE `occurrence_recorders`;
      DROP TABLE `taxa`;
      DROP TABLE `taxon_occurrences`;

From the bloodhound_new database, rename the tables:

      RENAME TABLE `bloodhound_new`.`agents` TO `bloodhound`.`agents`;
      RENAME TABLE `bloodhound_new`.`occurrences` TO `bloodhound`.`occurrences`;
      RENAME TABLE `bloodhound_new`.`occurrence_determiners` TO `bloodhound`.`occurrence_determiners`;
      RENAME TABLE `bloodhound_new`.`occurrence_recorders` TO `bloodhound`.`occurrence_recorders`;
      RENAME TABLE `bloodhound_new`.`taxa` TO `bloodhound`.`taxa`;
      RENAME TABLE `bloodhound_new`.`taxon_occurrences` TO `bloodhound`.`taxon_occurrences`;

Last of all, rebuild the Elasticsearch indices:

      RACK_ENV=production ./bin/populate_search.rb --rebuild

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
