#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_agents.rb [options]"

  opts.on("-r", "--refresh", "Refresh profile data") do
    options[:refresh] = true
  end

  opts.on("-p", "--poll", "Poll ORCID for new users") do
    options[:poll] = true
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

  opts.on("-a", "--all", "Update all user accounts.") do
    options[:all] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:refresh]
  User.find_each do |u|
    u.update_profile
    puts "#{u.fullname_reverse}".green
  end
end

if options[:poll]
  search = Bloodhound::OrcidSearch.new
  search.populate_new_users
end

if options[:orcid]
  u = User.find_or_create_by({ orcid: options[:orcid] })
  u.update_profile
  puts "#{u.fullname_reverse} created/updated".green
end

if options[:wikidata]
  u = User.find_or_create_by({ wikidata: options[:wikidata] })
  u.update_profile
  if !u.complete_wikicontent?
    u.destroy
    puts "#{u.wikidata} destroyed. Missing either family name, birth or death date".red
  else
    puts "#{u.fullname_reverse} created/updated".green
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

if options[:logged]
  User.where.not(visited: nil).find_each do |u|
    u.update_profile
    puts "#{u.fullname_reverse}".green
  end
end

if options[:all]
  User.find_each do |u|
    u.update_profile
    puts "#{u.fullname_reverse}".green
  end
end