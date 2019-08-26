#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_occurrence.rb [options]"

  opts.on("-g", "--gbifid [identifier]", Integer, "Refresh GBIF data for a gbifID") do |identifier|
    options[:identifier] = identifier
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:identifier]
  o = Occurrence.find(options[:identifier])
  o.update_from_gbif
end