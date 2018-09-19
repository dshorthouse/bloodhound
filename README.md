# Bloodhound
Proof-of-concept, Sinatra app to parse people names from structured biodiversity occurrence data, apply basic regular expressions and heuristics to disambiguate them, and to make these occurrence records as entities that can be claimed by authenticated users via [ORCID](https://orcid.org).

[![Build Status](https://travis-ci.org/dshorthouse/bloodhound.svg?branch=master)](https://travis-ci.org/dshorthouse/bloodhound)

## Requirements

1. ruby 2.5.1+
2. ElasticSearch 6.2.4+
3. MySQL 14.14+
4. Redis 4.0.9+

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

## Worker Queues

### Populate Agents

     $ COUNT=5 QUEUE=agent rake environment resque:workers

### Populate Taxa

     $ COUNT=5 QUEUE=taxon rake environment resque:workers

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