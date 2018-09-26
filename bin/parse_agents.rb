#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_agents.rb [options]"

  opts.on("-f", "--flush", "Flush parsed data") do |a|
    options[:flush] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:flush]
  Occurrence.connection.execute("UPDATE occurrences SET identifiedByParsed = NULL, recordedByParsed = NULL")
end

Sidekiq::Stats.new.reset

pbar = ProgressBar.create(title: "ParseAgents", total: Occurrence.count, autofinish: false, format: '%t %b>> %i| %e')
Occurrence.find_each do |o|
  Agent.enqueue(o)
  pbar.increment
end
pbar.finish