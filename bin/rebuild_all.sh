#!/bin/sh

./bin/populate_agents.rb --truncate
./bin/populate_taxa.rb --truncate
./bin/disambiguate_agents.rb --reset --reassign
./bin/populate_search.rb --rebuild-agents