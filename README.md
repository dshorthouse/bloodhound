# Bloodhound
Sinatra app to parse people names from structured biodiversity occurrence data, apply basic regular expressions and heuristics to disambiguate them, and then allow them to be claimed by authenticated users via [ORCID](https://orcid.org).

[![Build Status](https://travis-ci.org/dshorthouse/bloodhound.svg?branch=master)](https://travis-ci.org/dshorthouse/bloodhound)

## Recent Updates

- **September 29, 2018**: The core, parsing component of this project has been split off into a stand-alone ruby gem, [dwc_agent](https://rubygems.org/gems/dwc_agent).
- **October 12, 2018**: Used Neo4j to store weighted graphs of similarly structured people names as a quick mechanism to expand the list of users' candidate specimens & then present them in greatest to least probable.

## Requirements

1. ruby 2.5.1+
2. Elasticsearch 6.2.4+
3. MySQL 14.14+
4. Redis 4.0.9+
5. Apache Spark 2+
6. Neo4j

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

     $ ./bin/populate_agents.rb --truncate --directory /directory-to-spark-csv-files/
     $ sidekiq -c 40 -q agent -r ./environment.rb

### Step 3: Populate Taxa

     $ ./bin/populate_taxa.rb --truncate --directory /directory-to-spark-csv-files/
     $ sidekiq -c 40 -q taxon -r ./environment.rb

     $ ./bin/populate_taxa.rb --kingdoms
     $ sidekiq -c 40 kingdom -r ./environment.rb

### Step 4: Cluster Agents & Store in Neo4j

     $ ./bin/cluster_agents.rb --truncate --cluster
     $ sidekiq -c 40 -q cluster -r ./environment.rb

### Step 5: Populate Search in Elasticsearch

     $ ./bin/populate_search.rb --rebuild-agents

## Elasticsearch Snapshot & Restore

Notes to self because I never remember how to backup on my laptop and restore on the server:

### Make Snapshots for Both Indices

      curl -X PUT "localhost:9200/_snapshot/bloodhound_agents_backup" -H 'Content-Type: application/json' -d'
      {
          "type": "fs",
          "settings": {
              "location": "/Users/dshorthouse/Documents/es_backup/bloodhound_agents/",
              "compress": true
          }
      }
      '

      curl -X PUT "localhost:9200/_snapshot/bloodhound_agents_backup/all?wait_for_completion=true" -H 'Content-Type: application/json' -d '
      {
          "indices" : "bloodhound_agents",
          "ignore_unavailable" : true,
          "include_global_state" : false
      }
      '

      curl -X PUT "localhost:9200/_snapshot/bloodhound_users_backup" -H 'Content-Type: application/json' -d'
      {
          "type": "fs",
          "settings": {
              "location": "/Users/dshorthouse/Documents/es_backup/bloodhound_users/",
              "compress": true
          }
      }
      '

      curl -X PUT "localhost:9200/_snapshot/bloodhound_users_backup/all?wait_for_completion=true" -H 'Content-Type: application/json' -d '
      {
          "indices" : "bloodhound_users",
          "ignore_unavailable" : true,
          "include_global_state" : false
      }
      '

### Restore Snapshots for Both Indices

      $ curl -X POST "localhost:9200/bloodhound_agents/_close"
      $ curl -X POST "localhost:9200/_snapshot/bloodhound_agents_backup/all/_restore" -H 'Content-Type: application/json' -d '
      {
        "indices": "bloodhound_agents"
      }
      '
      $ curl -X POST "localhost:9200/bloodhound_agents/_open"

      $ curl -X POST "localhost:9200/bloodhound_users/_close"
      $ curl -X POST "localhost:9200/_snapshot/bloodhound_users_backup/all/_restore" -H 'Content-Type: application/json' -d '
      {
        "indices": "bloodhound_users"
      }
      '
      $ curl -X POST "localhost:9200/bloodhound_users/_open"

If Elasticsearch throws an error on the above, you may need to execute the following:

      $ curl -X PUT "localhost:9200/_settings" -H 'Content-Type: application/json' -d '
      {
        "index": {
          "blocks": {
            "read_only_allow_delete": "false"
          }
        }
      }
      '

      $ curl -X PUT "localhost:9200/bloodhound_agents/_settings" -H 'Content-Type: application/json' -d '
      {
        "index": {
          "blocks": {
            "read_only_allow_delete": "false"
          }
        }
      }
      '
      $ curl -X PUT "localhost:9200/bloodhound_users/_settings" -H 'Content-Type: application/json' -d '
      {
        "index": {
          "blocks": {
            "read_only_allow_delete": "false"
          }
        }
      }
      '
## Neo4j Dump & Restore

Notes to self because I never remember how to dump from my laptop and reload onto the server:

      neo4j-admin dump --database=<database> --to=<destination-path>
      neo4j-admin load --from=<archive-path> --database=<database> [--force]

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