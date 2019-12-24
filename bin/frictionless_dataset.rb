#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: frictionless_dataset.rb [options]. Create frictionless datasets."

  opts.on("-k", "--key [key]", String, "Create a datataset from a specific key") do |key|
    options[:key] = key
  end

  opts.on("-d", "--directory [directory]", String, "Directory to create zipped frictionless data package") do |directory|
    options[:directory] = directory
  end

  opts.on("-a", "--all", "Make data packages for all datasets that have at least one public claim") do
    options[:all] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:directory] && options[:key]
  dataset = Dataset.find_by_datasetKey(options[:key]) rescue nil
  if dataset
    puts "Starting #{dataset.title}...".yellow
    f = Bloodhound::FrictionlessData.new(uuid: options[:key], output_directory: options[:directory])
    f.create_package
    puts "Package created for #{options[:key]}".green
  else
    puts "Package #{options[:key]} not found".red
  end
elsif options[:directory] && options[:all]
  Dataset.find_each do |d|
    next if !d.has_claim?
    puts "Starting #{d.title}...".yellow
    f = Bloodhound::FrictionlessData.new(uuid: d.datasetKey, output_directory: options[:directory])
    f.create_package
    puts "Package created for #{d.datasetKey}".green
  end
end
