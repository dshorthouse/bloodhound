#!/bin/sh

./bin/populate_agents.rb --truncate
./bin/populate_taxa.rb --truncate
./bin/disambiguate_agents.rb --reset

./bin/update_agents.rb --all
./bin/populate_search.rb --rebuild-agents