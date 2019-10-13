#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_taxon_determiners.rb [options]"

  opts.on("-t", "--truncate", "Truncate data") do |a|
    options[:truncate] = true
  end

  opts.on("-p", "--populate", "Populate taxon_determiners table") do |a|
    options[:populate] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  ActiveRecord::Base.connection.execute("TRUNCATE taxon_determiners")
end

if options[:populate]
  count = Occurrence.maximum(:id)
  chunk = 100_000
  (1..count).step(chunk) do |n|
    puts n
    sql = "INSERT INTO
             taxon_determiners (taxon_id, agent_id)
           SELECT
             t.taxon_id, d.agent_id
           FROM
             occurrence_determiners d
           JOIN
             taxon_occurrences t ON d.occurrence_id = t.occurrence_id
           WHERE
             d.occurrence_id >= #{n} AND d.occurrence_id < #{n + chunk}"
    ActiveRecord::Base.connection.execute(sql)
  end
end