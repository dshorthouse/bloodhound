#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage:populate_search.rb [options]"

  opts.on("-i", "--rebuild-agents", "Rebuild the agent index") do |a|
    options[:rebuild_agents] = true
  end

  opts.on("-r", "--refresh", "Refresh the index") do |a|
    options[:refresh] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

index = Bloodhound::ElasticIndexer.new

if options[:refresh]
  index.refresh
end

if options[:rebuild_agents]
  index.delete
  index.create
  index.import_agents
  index.refresh
end