#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: merge_agents.rb [options]"

  opts.on("-s", "--sources 1,2,3,4", Array, "List of source agent ids (without spaces) to be merged") do |agent_ids|
    options[:sources] = agent_ids
  end

  opts.on("-d", "--destination id", Integer, "Destination agent id") do |agent_id|
    options[:destination] = agent_id
  end

  opts.on("-w", "--with-search", "Update with search") do |a|
    options[:search] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

index = Bloodhound::ElasticIndexer.new

if options[:sources] && options[:destination]
  sources = options[:sources].map(&:to_i)
  destination = options[:destination].to_i
  models = [
    "AgentDescription",
    "OccurrenceDeterminer",
    "OccurrenceRecorder",
    "TaxonDeterminer"
  ]
  Parallel.map(models.each, progress: "UpdateTables") do |model|
    model.constantize.where(agent_id: sources).update_all(agent_id: destination)
  end
  agents = Agent.where(id: sources)
  agents.update_all(canonical_id: destination)

  if options[:search]
    agents.find_each do |agent|
      index.delete_agent(agent) rescue nil
    end
  end
end
