#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: disambiguate_agents.rb [options]"

  opts.on("-w", "--write-graphics", "Write graphics files") do
    options[:write] = true
  end

  opts.on("-d", "--disambiguate", "Disambiguate family names") do
    options[:disambiguate] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

if options[:disambiguate]
  Sidekiq::Stats.new.reset
  write_graphics = options[:write] ? true : false
  duplicates = Agent.where(processed: false)
                    .where("family NOT LIKE '%.%'")
                    .where.not(given: ["", nil])
                    .group("family, LOWER(LEFT(given,1))")
                    .having('count(*) > 1')
                    .pluck(:id)
  duplicates.each do |id|
    data = { id: id, write_graphics: write_graphics }
    Sidekiq::Client.enqueue(Bloodhound::DisambiguateWorker, data)
  end

end