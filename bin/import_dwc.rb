#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage:import_dwc.rb [options]"

  opts.on("-f", "--file [file]", String, "File path to dwc archive file") do |file|
    options[:file] = file
  end

  opts.on("-d", "--directory [directory]", String, "Directory containing 1+ DwC archive file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

def import_file(dwc_file, progress = true)
  attributes = Occurrence.attribute_names
  attributes.shift

  dwc = DarwinCore.new(dwc_file)
  title = File.basename(dwc_file)
  file = File.new(dwc.core.file_path)
  batch_size = 5_000
  row_count = file.readlines.size
  total = (row_count < batch_size) ? 1 : row_count/batch_size
  if progress
    pbar = ProgressBar.create(title: title, total: total, autofinish: false, format: '%t %b>> %i| %e')
  end

  indexes = {}
  dwc.core.data[:field].each do |field|
    key = field[:attributes][:term].split("/")[-1]
    if attributes.include?(key)
      indexes[key.to_sym] = field[:attributes][:index]
    end
  end

  dwc.core.read(batch_size) do |data, errors|
    pbar.increment if progress
    records = data.map{|r| Occurrence.new(Hash[indexes.keys.zip(r.values_at(*indexes.values))]) }
    Occurrence.import records, validate: false
  end
  pbar.finish if progress
end

if options[:file]
  dwc_file = options[:file]
  raise "File not found" unless File.exists?(dwc_file)
  import_file(dwc_file)
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not foud" unless File.directory?(directory)
  accepted_formats = [".zip", ".gzip"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}
  Parallel.map(files.in_groups_of(3, false), progress: "Bulk Import") do |batch|
    batch.each do |file|
      import_file(File.join(directory, file), false) rescue puts File.basename(file)
    end
  end
end