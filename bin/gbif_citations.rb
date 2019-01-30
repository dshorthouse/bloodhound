#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gbif_citations.rb [options]. Check and import citations of downloaded specimens"

  opts.on("-f", "--first-page", "Download new data packages and parse for gbifIDs") do
    options[:first] = true
  end

  opts.on("-a", "--all", "Download all data packages and parse for gbifIDs") do
    options[:all] = true
  end

  opts.on("-p", "--process", "Process all data packages by downloading and importing") do
    options[:process] = true
  end

  opts.on("-d", "--delete", "Delete irrelevant article_occurrences entries") do
    options[:delete] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

first_page = (options[:first]) ? { first_page_only: true } : { first_page_only: false }
tracker = Bloodhound::GbifTracker.new(first_page)

if options[:first] || options[:all]
  tracker.create_package_records
end

if options[:process]
  tracker.process_data_packages
end

if options[:delete]
  tracker.flush_irrelevant_entries
end