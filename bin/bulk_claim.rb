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

  opts.on("-w", "--where [where]", String, "WHERE as JSON on occurrence records, eg '{ \"institutionCode\" : \"CAN\" }' or a LIKE statement '{ \"scientificName LIKE ?\":\"Bolbelasmus %\"}'") do |where|
    options[:where] = where
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
    claimed = user.user_occurrences.pluck(:occurrence_id)

    if !options[:where]
      recordings = agent.occurrence_recorders.pluck(:occurrence_id)
      determinations = agent.occurrence_determiners.pluck(:occurrence_id)
    else
      where_hash = JSON.parse options[:where].gsub('=>', ':')

      recordings = where_hash.inject(agent.recordings) do |o, a|
        if a[0].include?(" ?")
          o.send("where", a)
        else
          o.send("where", Hash[[a]])
        end
      end.pluck(:gbifID)

      determinations = where_hash.inject(agent.determinations) do |o, a|
        if a[0].include?(" ?")
          o.send("where", a)
        else
          o.send("where", Hash[[a]])
        end
      end.pluck(:gbifID)
    end

    uniq_recordings = (recordings - determinations) - claimed
    uniq_determinations = (determinations - recordings) - claimed
    both = (recordings & determinations) - claimed

    if !options[:ignore]
      puts "Claiming unique recordings...".yellow
      UserOccurrence.import uniq_recordings.map{|o| {
        user_id: user.id,
        occurrence_id: o,
        action: "recorded",
        created_by: user.id
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true

      puts "Claiming unique determinations...".yellow
      UserOccurrence.import uniq_determinations.map{|o| {
        user_id: user.id,
        occurrence_id: o,
        action: "identified",
        created_by: user.id
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true

      puts "Claiming recordings and determinations...".yellow
      UserOccurrence.import both.map{|o| {
        user_id: user.id,
        occurrence_id: o,
        action: "recorded,identified",
        created_by: user.id
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true

      puts "#{agent.fullname} data claimed for #{user.fullname}".green
    else
      all = (recordings + determinations).uniq - claimed
      puts "Ignoring occurrences...".yellow
      UserOccurrence.import all.map{|o| {
        user_id: user.id,
        occurrence_id: o,
        action: nil,
        visible: 0,
        created_by: user.id
      } }, batch_size: 500, validate: false, on_duplicate_key_ignore: true
      puts "#{agent.fullname} data ignored for #{user.fullname}".red
    end
  end

end