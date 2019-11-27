#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gbif_datasets.rb [options]. Check and import datasets on GBIF"

  opts.on("-a", "--all", "Download metadata for all datasets and create entries if missing") do
    options[:all] = true
  end

  opts.on("-p", "--populate", "Populate datasets from occurrence table") do
    options[:populate] = true
  end

  opts.on("-d", "--datasetkey [datasetkey]", String, "Create/update metadata for a single dataset") do |datasetkey|
    options[:datasetkey] = datasetkey
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

datasets = Bloodhound::GbifDataset.new

if options[:all]
  datasets.create_records
elsif options[:populate]
  keys = Occurrence.distinct.pluck(:datasetKey).reject!(&:empty?)
  Dataset.import keys.map{|k| { datasetKey: k }}, batch_size: 1_000, on_duplicate_key_ignore: true, validate: false
  Dataset.where(title: nil).find_each do |d|
    datasets.process_dataset(d.datasetKey)
    puts d.datasetKey.green
  end
elsif options[:datasetkey]
  datasets.process_dataset(options[:datasetkey])
end
