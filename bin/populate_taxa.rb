#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_taxa.rb [options]"

  opts.on("-t", "--truncate", "Truncate data") do |a|
    options[:truncate] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  Occurrence.connection.execute("TRUNCATE TABLE taxa")
  Occurrence.connection.execute("TRUNCATE TABLE taxon_occurrences")
  Occurrence.connection.execute("TRUNCATE TABLE taxon_determiners")
end

Sidekiq::Stats.new.reset

pbar = ProgressBar.create(title: "PopulatingTaxa", total: Occurrence.count, autofinish: false, format: '%t %b>> %i| %e')
Occurrence.find_each do |o|
  Taxon.enqueue(o)
  pbar.increment
end
pbar.finish

puts "Populating kingdoms..."
Taxon.populate_kingdoms