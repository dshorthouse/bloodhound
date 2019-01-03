#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_agents.rb [options]"

  opts.on("-r", "--refresh", "Refresh ORCID data") do
    options[:refresh] = true
  end

  opts.on("-p", "--poll", "Poll ORCID for new users") do
    options[:poll] = true
  end

  opts.on("-o", "--orcid [ORCID]", String, "Add/update user with an ORCID") do |orcid|
    options[:orcid] = orcid
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
    u.update_orcid_profile
    puts "#{u.fullname_reverse}".green
  end
end

if options[:poll]
  search = Bloodhound::OrcidSearch.new
  search.populate_new_users
end

if options[:orcid]
  u = User.find_or_create_by({ orcid: options[:orcid] })
  u.update_orcid_profile
  puts "#{u.fullname_reverse} created/updated".green
end

if options[:logged]
  User.where.not(visited: nil).find_each do |u|
    u.update_orcid_profile
    puts "#{u.fullname_reverse}".green
  end
end

if options[:all]
  User.find_each do |u|
    u.update_orcid_profile
    puts "#{u.fullname_reverse}".green
  end
end