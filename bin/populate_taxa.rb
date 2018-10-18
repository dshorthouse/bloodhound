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

  opts.on("-d", "--directory [directory]", String, "Directory containing csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-k", "--kingdoms", "Populate kingdoms") do
    options[:kingdoms] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  tables = [
    "taxa",
    "taxon_occurrences",
    "taxon_determiners"
  ]
  tables.each do |table|
    Occurrence.connection.execute("TRUNCATE TABLE #{table}")
  end
  Sidekiq::Stats.new.reset
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)
  accepted_formats = [".csv"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}

  files.each do |file|
    file_path = File.join(options[:directory], file)
    Taxon.enqueue(file_path)
  end
end

if options[:kingdoms]
  Taxon.where(kingdom: nil).find_each do |t|
    Taxon.enqueue_kingdoms(t.id)
  end
end

=begin

AFTER taxon queue is empty of jobs, must execute the following:

  sql = "INSERT INTO 
          taxon_determiners 
            (taxon_id, agent_id) 
         SELECT
           t.taxon_id, d.agent_id
         FROM 
           occurrence_determiners d 
         JOIN taxon_occurrences t ON d.occurrence_id = t.occurrence_id"

  Occurrence.connection.execute(sql)

=end
