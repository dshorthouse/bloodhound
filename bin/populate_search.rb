#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage:populate_search.rb [options]"

  opts.on("-r", "--rebuild", "Rebuild the index") do |a|
    options[:rebuild] = true
  end

  opts.on("-w", "--refresh", "Refresh the index") do |a|
    options[:refresh] = true
  end

  opts.on("-i", "--index [directory]", String, "Rebuild a particular index. Acccepted are agent, user, or organization") do |index|
    options[:index] = index
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
  puts "Importing agents..."
  index.import_agents
  index.refresh_agent_index

  index.delete_user_index
  index.create_user_index
  puts "Importing users..."
  index.import_users
  index.refresh_user_index

  index.delete_organization_index
  index.create_organization_index
  puts "Importing organizations..."
  index.import_organizations
  index.refresh_organization_index
end

if options[:index]
  if ["agent","user","organization"].include?(options[:index])
    index.send("delete_#{options[:index]}_index")
    index.send("create_#{options[:index]}_index")
    puts "Importing #{options[:index]}s..."
    index.send("import_#{options[:index]}s")
    index.send("refresh_#{options[:index]}_index")
  else
    puts "Accepted values are agent, user, or organization"
  end
end