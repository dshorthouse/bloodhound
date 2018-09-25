#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'
require 'fileutils'
require 'tempfile'

# Imports a occurrence.csv from an unzipped DwC file

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage:import_csv.rb [options]"

  opts.on("-f", "--file [file]", String, "File path to csv file") do |file|
    options[:file] = file
  end

  opts.on("-t", "--truncate", "Truncate data") do |a|
    options[:truncate] = true
  end

  opts.on("-d", "--directory [directory]", String, "Directory containing 1+ csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

def import_file(file_path)
  Sidekiq::Stats.new.reset

  attributes = Occurrence.attribute_names
  attributes << "gbifID"

  batch_size   = 50_000
  line_count = `wc -l "#{file_path}"`.strip.split(' ')[0].to_i

  pbar_options = {
    title: "PopulatingOccurrences",
    total: line_count/batch_size,
    autofinish: false,
    format: '%t %b>> %i| %e'
  }

  pbar = ProgressBar.create(pbar_options)

  csv_options = {
    col_sep: "\t",
    row_sep: "\n"
  }

  db_folder = File.join(File.expand_path(File.dirname(__FILE__)), "..", "db")

  File.open(file_path) do |file|
    header = file.first.gsub(csv_options[:row_sep], "").split(csv_options[:col_sep])
    indices = header.each_with_index.select{|v,i| i if attributes.include?(v)}.to_h
    indices["id"] = indices["gbifID"]
    indices.delete("gbifID")

    file.lazy.each_slice(batch_size) do |lines|
      pbar.increment
      tmp_file = File.join(db_folder, ('a'..'z').to_a.shuffle[0,8].join + ".csv")
      CSV.open(tmp_file, 'w') do |csv|
        lines.each do |line|
          csv << line.gsub(csv_options[:row_sep], "")
                   .split(csv_options[:col_sep])
                   .values_at(*indices.values)
        end
      end
      Occurrence.enqueue({indices: indices, tmp_file: tmp_file, csv_options: csv_options})
    end
  end
  pbar.finish
end

if options[:truncate]
  Occurrence.connection.execute("TRUNCATE TABLE occurrences")
end

if options[:file]
  csv_file = options[:file]
  raise "File not found" unless File.exists?(csv_file)
  import_file(csv_file)
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)
  accepted_formats = [".csv"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}
  files.each do |file|
    import_file(file)
  end
end