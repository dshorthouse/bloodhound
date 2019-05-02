#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: zenodo.rb [options]"

  opts.on("-n", "--new", "Push new claims data to Zenodo") do
    options[:new] = true
  end

  opts.on("-a", "--all", "Push new versions to Zenodo") do
    options[:all] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:new]
  User.where.not(orcid: nil).where.not(zenodo_access_token: nil).find_each do |u|
    z = Bloodhound::Zenodo.new(hash: u.zenodo_access_token)
    u.zenodo_access_token = z.refresh_token
    u.save

    doi_id = z.new_deposit(name: u.fullname_reverse, orcid: u.orcid)
    id = doi_id[:recid]
    csv = Bloodhound::IO.csv_stream_occurrences(u.visible_occurrences)
    z.add_file_enum(id: id, enum: csv, file_name: u.orcid + ".csv")
    #TODO: add JSON-LD document
    pub = z.publish(id: id)
    u.zenodo_doi = pub[:doi]
    u.zenodo_concept_doi = pub[:conceptdoi]
    u.save
  end
elsif options[:all]
  #TODO: use u.zenodo_doi & strip off ID portion, make new version and publish it
  #TODO: ensure that new versions do not pollute ORCID account somehow
end