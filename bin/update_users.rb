#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_agents.rb [options]"

  opts.on("-c", "--country-codes", "Update country codes") do
    options[:country_codes] = true
  end

  opts.on("-p", "--poll-orcid", "Poll ORCID for new accounts") do
    options[:poll_orcid] = true
  end

  opts.on("-w", "--poll-wikidata", "Poll wikidata for new accounts") do
    options[:poll_wikidata] = true
  end

  opts.on("-o", "--orcid [ORCID]", String, "Add/update user with an ORCID") do |orcid|
    options[:orcid] = orcid
  end

  opts.on("-k", "--wikidata [WIKIDATA]", String, "Add/update user with a Wikidata identifier") do |wikidata|
    options[:wikidata] = wikidata
  end

  opts.on("-f", "--file [FILE]", String, "Import users using a csv with a single column of either wikidata or ORCID numbers") do |file|
    options[:file] = file
  end

  opts.on("-l", "--logged-in", "Update ORCID data for user accounts that have logged in.") do
    options[:logged] = true
  end

  opts.on("-i", "--public", "Update all public accounts") do
    options[:public] = true
  end

  opts.on("-u", "--update-orcid", "Update all ORCID accounts.") do
    options[:update_orcid] = true
  end

  opts.on("-v", "--update-wikidata", "Update all wikidata accounts.") do
    options[:update_wikidata] = true
  end

  opts.on("-a", "--all", "Update all user accounts.") do
    options[:all] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:poll_orcid]
  search = Bloodhound::OrcidSearch.new
  search.populate_new_users
end

if options[:poll_wikidata]
  search = Bloodhound::WikidataSearch.new
  search.populate_new_users
end

if options[:country_codes]
  User.find_each do |user|
    if !user.country.blank?
      codes = []
      user.country.split("|").each do |country|
        codes << IsoCountryCodes.search_by_name(country).first.alpha2 rescue nil
      end
      if !codes.compact.empty?
        user.country_code = codes.compact.join("|")
        user.save
      else
        puts "#{user.fullname_reverse}".red
      end
    end
  end
end

if options[:file]
  mime_type = `file --mime -b "#{options[:file]}"`.chomp
  raise RuntimeError, 'File must be a csv' if !mime_type.include?("text/plain")
  CSV.foreach(options[:file]) do |row|
    next if !row[0].is_orcid? && !row[0].is_wiki_id?
    if row[0].is_wiki_id?
      u = User.find_or_create_by({ wikidata: row[0] })
    elsif row[0].is_orcid?
      u = User.find_or_create_by({ orcid: row[0] })
    end
    u.update_profile
    if !u.complete_wikicontent?
      u.destroy
      puts "#{u.wikidata} destroyed. Missing either family name, birth or death date".red
    else
      puts "#{u.fullname_reverse} created/updated".green
    end
  end
end

if options[:wikidata]
  u = User.find_or_create_by({ wikidata: options[:wikidata] })
  u.update_profile
  if !u.complete_wikicontent?
    u.destroy
    puts "#{u.wikidata} destroyed. Missing either family name, birth or death date".red
  else
    cache_clear "fragments/#{u.identifier}"
    puts "#{u.fullname_reverse} created/updated".green
  end
elsif options[:orcid]
  u = User.find_or_create_by({ orcid: options[:orcid] })
  u.update_profile
  cache_clear "fragments/#{u.identifier}"
  puts "#{u.fullname_reverse} created/updated".green
elsif options[:logged]
  User.where.not(visited: nil).find_each do |u|
    u.update_profile
    cache_clear "fragments/#{u.identifier}"
    puts "#{u.fullname_reverse}".green
  end
elsif options[:public]
  User.where(is_public: true).find_each do |u|
    u.update_profile
    cache_clear "fragments/#{u.identifier}"
    puts "#{u.fullname_reverse}".green
  end
elsif options[:all]
  User.order(:family).find_each do |u|
    u.update_profile
    cache_clear "fragments/#{u.identifier}"
    puts "#{u.fullname_reverse}".green
  end
elsif options[:update_wikidata]
  User.where.not(wikidata: nil).order(:family).find_each do |u|
    u.update_profile
    cache_clear "fragments/#{u.identifier}"
    puts "#{u.fullname_reverse}".green
  end
elsif options[:update_orcid]
  User.where.not(orcid: nil).order(:family).find_each do |u|
    u.update_profile
    cache_clear "fragments/#{u.identifier}"
    puts "#{u.fullname_reverse}".green
  end
end