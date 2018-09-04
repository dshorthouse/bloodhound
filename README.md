# Bloodhound
Proof-of-concept, Sinatra app to parse people names from structured biodiversity occurrence data, apply basic regular expressions and heuristics to disambiguate them, and to make these occurrence records as entities that can be claimed by authenticated users via [ORCID](https://orcid.org).

[![Build Status](https://travis-ci.org/dshorthouse/bloodhound.svg?branch=master)](https://travis-ci.org/dshorthouse/bloodhound)

## Requirements

1. ruby 2.5.1
2. ElasticSearch 6.2.4
3. MySQL 14.14

## Installation

     $ git clone https://github.com/dshorthouse/bloodhound.git
     $ cd bloodhound
     $ gem install bundler
     $ bundle install
     $ mysql -u root bloodhound < db/bloodhound.sql
     $ cp config.yml.sample config.yml
     # Adjust content of config.yml
     $ ./application.rb
     # See utilities in bin/ for importing and loading data, creation of search index

## Elasticsearch Snapshot & Restore

Notes to self:

### Make Snapshot

      curl -X PUT "localhost:9200/_snapshot/bloodhound_backup" -H 'Content-Type: application/json' -d'
      {
          "type": "fs",
          "settings": {
              "location": "/home/dshorthouse/es_backup",
              "compress": true
          }
      }
      '

      curl -X PUT "localhost:9200/_snapshot/bloodhound_backup/all?wait_for_completion=true" -H 'Content-Type: application/json' -d '
      {
          "indices" : "bloodhound",
          "ignore_unavailable" : true,
          "include_global_state" : false
      }
      '

### Restore Snapshot

      $ curl -X POST "localhost:9200/bloodhound/_close"
      $ curl -X POST "localhost:9200/_snapshot/bloodhound_backup/all/_restore" -H 'Content-Type: application/json' -d '
      {
        "indices": "bloodhound"
      }
      '
      $ curl -X POST "localhost:9200/bloodhound/_open"