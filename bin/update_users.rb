#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_agents.rb [options]"

  opts.on("-r", "--refresh", "Refresh ORCID data") do |a|
    options[:refresh] = true
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
