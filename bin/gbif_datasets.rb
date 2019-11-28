#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gbif_datasets.rb [options]. Check and import datasets on GBIF"

  opts.on("-p", "--populate", "Populate datasets from occurrence table") do
    options[:populate] = true
  end

  opts.on("-a", "--all", "Refresh metadata for all datasets") do
    options[:all] = true
  end

  opts.on("-u", "--update", "Add metadata for new datasets, not previously downloaded") do
    options[:update] = true
  end

  opts.on("-f", "--flush", "Flush previously ingested datasets that are no longer present in the occurrence data") do
    options[:flush] = true
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

if options[:populate]
  keys = Occurrence.distinct.pluck(:datasetKey)
  Dataset.import keys.map{|k| { datasetKey: k }}, batch_size: 1_000, on_duplicate_key_ignore: true, validate: false
  datasets.update_all
elsif options[:all]
  datasets.update_all
elsif options[:update]
  occurrence_keys = Occurrence.distinct.pluck(:datasetKey)
  dataset_keys = Dataset.pluck(:datasetKey)
  Dataset.where(datasetKey: occurrence_keys - dataset_keys).find_each do |d|
    datasets.process_dataset(d.datasetkey)
  end
elsif options[:flush]
  occurrence_keys = Occurrence.distinct.pluck(:datasetKey)
  dataset_keys = Dataset.pluck(:datasetKey)
  Dataset.where(datasetKey: dataset_keys - occurrence_keys).destroy_all
elsif options[:datasetkey]
  datasets.process_dataset(options[:datasetkey])
end
