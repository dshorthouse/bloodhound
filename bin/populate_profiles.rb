#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_profiles.rb [options]"

  opts.on("-r", "--reset", "Reset profiles") do |a|
    options[:reset] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:reset]
  Agent.connection.execute("UPDATE agents SET email = NULL, position = NULL, affiliation = NULL, processed_profile = NULL")
end

puts "Populating profiles..."
Agent.populate_profiles