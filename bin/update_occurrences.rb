#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: update_occurrences.rb [options]"

  opts.on("-o OCCURRENCES", "--occurrences 1,2,3,4", Array, "Update a list of occurrences without spaces") do |o|
    options[:occurrences] = o
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

index = Bloodhound::ElasticIndexer.new

if options[:occurrences]
  occurrences = options[:occurrences]
  if !occurrences.is_a?(Array)
    puts opts
    exit
  else
    occurrences.each do |id|
      index.update_occurrence(Occurrence.find(id.to_i))
    end
  end
end

