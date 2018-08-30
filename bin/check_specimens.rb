#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: check_changes.rb [options]"

  opts.on("-a", "--all", "Check all linked specimens") do
    options[:all] = true
  end

  opts.on("-o", "--orcid [orcid]", String, "Check a user's specimens") do |orcid|
    options[:orcid] = orcid
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

if options[:all]
  Bloodhound::CheckSpecimens.all
end

if options[:orcid]
  Bloodhound::CheckSpecimens.user(options[:orcid])
end