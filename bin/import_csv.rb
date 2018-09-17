#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'
require 'fileutils'

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage:import_csv.rb [options]"

  opts.on("-f", "--file [file]", String, "File path to csv file") do |file|
    options[:file] = file
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
  attributes = Occurrence.attribute_names.map(&:downcase)
  attributes << "gbifid"

  header = File.open(file_path, &:readline).gsub("\n", "").split("\t")
  indices = header.each_with_index.select{|v,i| i if attributes.include?(v.downcase)}.to_h
  indices["id"] = indices["gbifID"]
  indices.delete("gbifID")

  time = Time.now.to_i

  chunked_dir = "/tmp/#{time}/"
  FileUtils.mkdir(chunked_dir)
  
  #split files
  puts "Splitting the csv..."
  system("split -l 100000 #{file_path} #{chunked_dir}")

  tmp_files = Dir.entries(chunked_dir).map{|f| File.join(chunked_dir, f) if !File.directory?(f)}.compact
  
  #remove the header row from the first file
  system("tail -n +2 #{tmp_files[0]} > #{tmp_files[0]}.new && mv -f #{tmp_files[0]}.new #{tmp_files[0]}")

  #load data in parallel
  Parallel.map(tmp_files.each, progress: "Importing CSV", processes: 6) do |file|
    output = file + ".csv"
    CSV.open(output, 'w') do |csv|
      CSV.foreach(file, options = { col_sep: "\t", quote_char: "\x00", liberal_parsing: true }) do |row|
        csv << row.values_at(*indices.values).map {|s| s.gsub("\\", '') if !s.nil?}
      end
    end
    sql = "LOAD DATA INFILE '#{output}' 
           INTO TABLE occurrences 
           CHARACTER SET UTF8 
           FIELDS TERMINATED BY ',' 
           OPTIONALLY ENCLOSED BY '\"'
           LINES TERMINATED BY '\n'
           (" + indices.keys.join(",") + ")"
    Occurrence.connection.execute sql
  end
  FileUtils.rm_rf(chunked_dir)
end

if options[:file]
  csv_file = options[:file]
  raise "File not found" unless File.exists?(csv_file)
  import_file(csv_file)
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not foud" unless File.directory?(directory)
  accepted_formats = [".csv"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}
  files.each do |file|
    import_file(File.join(directory, file))
  end
end