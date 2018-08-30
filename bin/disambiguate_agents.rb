#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: disambiguate_agents.rb [options]"

  opts.on("-r", "--reset", "Reset") do |a|
    options[:reset] = true
  end

  opts.on("-w", "--write-graphics", "Write graphics files") do
    options[:write] = true
  end

  opts.on("-x", "--reassign", "Reassign data") do
    options[:reassign] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

graphs = Bloodhound::AgentDisambiguator.new

if options[:reset]
  graphs.reset
end

if options[:write]
  graphs.write_graphics = true
end

puts "Disambiguating agents..."
graphs.disambiguate

if options[:reassign]
  graphs.reassign_data
end