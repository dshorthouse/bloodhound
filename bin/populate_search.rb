#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage:populate_search.rb [options]"

  opts.on("-i", "--rebuild", "Rebuild the index") do |a|
    options[:rebuild] = true
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

if options[:rebuild]
  index.delete_agent_index
  index.create_agent_index
  index.import_agents
  index.refresh_agent_index

  index.delete_user_index
  index.create_user_index
  index.import_users
  index.refresh_user_index
end