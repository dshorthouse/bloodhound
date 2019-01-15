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

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:isni]
  Organization.where("id > 2762").find_each do |o|
    isni = o.update_isni
    puts "#{o.id}: #{isni}"
    sleep(0.1)
  end
end