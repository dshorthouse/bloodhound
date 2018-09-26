#!/bin/sh

./bin/parse_agents.rb --flush
./bin/populate_taxa.rb --truncate
./bin/disambiguate_agents.rb --reset --reassign
./bin/populate_search.rb --rebuild-agents