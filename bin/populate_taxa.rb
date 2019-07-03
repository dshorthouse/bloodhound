#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
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
    group = []
    CSV.foreach(file_path, :headers => true).with_index do |row, i|
      group << [row.to_hash]
      next if i % 1000 != 0
      Sidekiq::Client.push_bulk({ 'class' => Bloodhound::TaxonWorker, 'args' => group })
      puts "#{file} ... #{i.to_s.green}"
      group = []
    end
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
