#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bulk_claim.rb [options]"

  opts.on("-a", "--agent [agent_id]", Integer, "Local agent identifier") do |agent_id|
    options[:agent_id] = agent_id
  end

  opts.on("-o", "--orcid [orcid]", String, "ORCID identifier for user") do |orcid|
    options[:orcid] = orcid
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

if !options[:agent_id] || !options[:orcid]
  puts "ERROR: Both -a and -o are required".red
else
  agent = Agent.find(options[:agent_id])
  user = User.find_by_orcid(options[:orcid])

  if agent.nil? || user.nil?
    puts "ERROR: either agent or user not found".red
    exit
  else
    recordings = agent.occurrence_recorders.pluck(:occurrence_id)
    determinations = agent.occurrence_determiners.pluck(:occurrence_id)

    uniq_recordings = recordings - determinations
    uniq_determinations = determinations - recordings
    both = recordings & determinations

    puts "Claiming unique recordings...".yellow
    UserOccurrence.import uniq_recordings.map{|o| { user_id: user.id, occurrence_id: o, action: "recorded", created_by: user.id} }

    puts "Claiming unique determinations...".yellow
    UserOccurrence.import uniq_determinations.map{|o| { user_id: user.id, occurrence_id: o, action: "identified", created_by: user.id} }

    puts "Claiming recordings and determinations...".yellow
    UserOccurrence.import both.map{|o| { user_id: user.id, occurrence_id: o, action: "recorded,identified", created_by: user.id} }
    
    puts "#{agent.fullname} data claimed by #{user.fullname}".green
  end

end