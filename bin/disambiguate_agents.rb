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
  duplicates = Agent.where("family NOT LIKE '%.%'")
                    .group(:family).count
                    .map{ |k,v| k if v > 1 }.compact
  duplicates.each do |family|
    #Only need one of the ids in the bundle to disambiguate the whole lot
    agent = Agent.find_by_family(family)
    #Check to see if any in the bundle have already been disambiguated
    if !agent.disambiguated?
      data = { id: agent.id, write_graphics: write_graphics }
      Sidekiq::Client.enqueue(Bloodhound::DisambiguateWorker, data)
    end
  end
end