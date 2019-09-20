#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bulk_claim.rb [options]. Assumes collector and determiner are spelled exactly the same."

  opts.on("-a", "--agent [agent_id]", Integer, "Local agent identifier") do |agent_id|
    options[:agent_id] = agent_id
  end

  opts.on("-c", "--conditions [conditions]", String, "executes a WHERE as JSON on occurrence records, eg '{ \"institutionCode\" : \"CAN\" }' or a LIKE statement '{ \"scientificName LIKE ?\":\"Bolbelasmus %\"}'") do |conditions|
    options[:conditions] = conditions
  end

  opts.on("-i", "--ignore", "Ignore all selections") do
    options[:ignore] = true
  end

  opts.on("-o", "--orcid [orcid]", String, "ORCID identifier for user") do |orcid|
    options[:orcid] = orcid
  end

  opts.on("-k", "--wikidata [wikidata]", String, "Wikidata identifier for user") do |wikidata|
    options[:wikidata] = wikidata
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if !options[:agent_id] || [options[:orcid], options[:wikidata]].compact.empty?
  puts "ERROR: Both -a and -o or -w are required".red
else
  agent = Agent.find(options[:agent_id])

  if options[:orcid]
    user = User.find_by_orcid(options[:orcid])
  elsif options[:wikidata]
    user = User.find_by_wikidata(options[:wikidata])
  end

  if agent.nil? || user.nil?
    puts "ERROR: either agent or user not found".red
    exit
  else
    result = user.bulk_claim(agent: agent, conditions: options[:conditions], ignore: options[:ignore])
    puts result.green
  end

end