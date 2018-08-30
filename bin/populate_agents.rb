#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_agents.rb [options]"

  opts.on("-t", "--truncate", "Truncate data") do |a|
    options[:truncate] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  tables = [
    "agents",
    "descriptions",
    "occurrence_determiners", 
    "occurrence_recorders", 
    "agent_descriptions",
    "taxon_determiners"
  ]
  tables.each do |table|
    Occurrence.connection.execute("TRUNCATE TABLE #{table}")
  end
end

Occurrence.populate_agents
Description.populate_agents