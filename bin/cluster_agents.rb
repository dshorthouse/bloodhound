#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: cluster_agents.rb [options]"

  opts.on("-c", "--cluster", "Cluster agents by family name") do
    options[:cluster] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

if options[:cluster]
  Sidekiq::Stats.new.reset
  write_graphics = options[:write] ? true : false
  duplicates = Agent.where("family NOT LIKE '%.%'")
                    .where.not(given: ["", nil])
                    .group("family, LOWER(LEFT(given,1))")
                    .having('count(*) > 1')
                    .pluck(:id)
  duplicates.each do |id|
    Sidekiq::Client.enqueue(Bloodhound::ClusterWorker, id)
  end

end