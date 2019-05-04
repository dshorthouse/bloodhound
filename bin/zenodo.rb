#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: zenodo.rb [options]"

  opts.on("-n", "--new", "Push brand new claims data to Zenodo") do
    options[:new] = true
  end

  opts.on("-a", "--all", "Push new versions to Zenodo") do
    options[:all] = true
  end

  opts.on("-r", "--refresh", "Refresh all Zenodo tokens") do
    options[:refresh] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:new]
  User.where.not(orcid: nil)
      .where.not(zenodo_access_token: nil)
      .where(zenodo_doi: nil).find_each do |u|
    z = Bloodhound::Zenodo.new(hash: u.zenodo_access_token)
    u.zenodo_access_token = z.refresh_token
    u.save

    doi_id = z.new_deposit(name: u.fullname_reverse, orcid: u.orcid)
    id = doi_id[:recid]
    csv = Bloodhound::IO.csv_stream_occurrences(u.visible_occurrences)
    z.add_file_enum(id: id, enum: csv, file_name: u.orcid + ".csv")
    json = Bloodhound::IO.jsonld_stream(u)
    z.add_file_string(id: id, string: json, file_name: u.orcid + ".json")
    pub = z.publish(id: id)
    u.zenodo_doi = pub[:doi]
    u.zenodo_concept_doi = pub[:conceptdoi]
    u.save
    puts "#{u.fullname_reverse}".green
  end
elsif options[:all]
  #TODO: what is periodicity? trigger?
  User.where.not(zenodo_doi: nil).limit(3).find_each do |u|
    z = Bloodhound::Zenodo.new(hash: u.zenodo_access_token)
    u.zenodo_access_token = z.refresh_token
    u.save

    old_id = u.zenodo_doi.split(".").last
    doi_id = z.new_version(id: old_id)

    id = doi_id[:recid]
    files = z.list_files(id: id).map{|f| f[:id]}
    files.each do |file_id|
      z.delete_file(id: id, file_id: file_id)
    end

    csv = Bloodhound::IO.csv_stream_occurrences(u.visible_occurrences)
    z.add_file_enum(id: id, enum: csv, file_name: u.orcid + ".csv")
    json = Bloodhound::IO.jsonld_stream(u)
    z.add_file_string(id: id, string: json, file_name: u.orcid + ".json")
    begin
      pub = z.publish(id: id)
      u.zenodo_doi = pub[:doi]
      u.save
      puts "#{u.fullname_reverse}".green
    rescue
      z.discard_version(id: id)
      puts "#{u.fullname_reverse}".red
    end
  end
end

if options[:refresh]
  User.where.not(zenodo_access_token: nil).find_each do |u|
    z = Bloodhound::Zenodo.new(hash: u.zenodo_access_token)
    u.zenodo_access_token = z.refresh_token
    u.save
  end
end