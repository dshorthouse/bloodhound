#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: add_agent.rb [options]"

  opts.on("-a", "--agent id", Integer, "Add an agent to the index") do |agent|
    options[:agent] = agent
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

index = Bloodhound::ElasticIndexer.new

if options[:agent]
  agent = Agent.find(options[:agent])
  index.add_agent(agent)
end