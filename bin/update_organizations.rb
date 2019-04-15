#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_organizations.rb [options]"

  opts.on("-u", "--update_isni", "Update ISNI data from Ringgold or GRID identifiers") do
    options[:isni] = true
  end

  opts.on("-c", "--update_codes", "Gather and update institutionCodes from Wikidata") do
    options[:codes] = true
  end

  opts.on("-w", "--update_wiki", "Gather and update coordinates and wikidata Q identifers from Wikidata") do
    options[:wikidata] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:isni]
  Organization.where.not(isni: nil).find_each do |o|
    isni = o.update_isni
    puts "#{o.id}: #{isni}"
    sleep(0.1)
  end
end

if options[:codes]
  Organization.where(institution_codes: nil).find_each do |o|
    codes = o.update_institution_codes
    if !codes.empty?
      puts "#{o.name}: #{o.institution_codes}".green
    else
      puts "#{o.name}".red
    end
    sleep(0.25)
  end
end

if options[:wikidata]
  Organization.where(wikidata: nil).find_each do |o|
    wikicode = o.update_wikidata
    if wikicode
      puts "#{o.name}: #{o.wikidata}".green
    else
      puts "#{o.name}".red
    end
    sleep(0.25)
  end
end
