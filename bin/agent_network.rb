#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}
options[:type] = "d3"
options[:depth] = 1

OptionParser.new do |opts|
  opts.banner = "Usage:agent_network.rb [options]"

  opts.on("-e", "--each-agent", "Generate graph files for each agent") do |a|
    options[:each_agent] = true
  end

  opts.on("-s", "--all-agents", "Generate single graph file for all agents") do |a|
    options[:all_agents] = true
  end

  opts.on("-a", "--agent-id N", Integer, "Generate graph file for single agent") do |a|
    options[:agent_id] = a
  end

  opts.on("-t", "--type [TYPE]", "Type of output, options are dot or d3") do |t|
    if ['dot', 'd3'].include? t
      options[:type] = t
    end
  end

  opts.on("-d", "--depth N", Integer, "The depth of the agent network") do |d|
    options[:depth] = d
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

if options[:all_agents]
  graph = Bloodhound::SocialNetwork.new
  graph.build
  graph.write_to_graphic_file('svg', File.join(Sinatra::Application.settings.root, 'public/images/collector-network'))
elsif options[:each_agent]
  puts 'Starting to create network graphs for each agent as ' + options[:type]
  count = 0
  agents = Agent.where("id = canonical_id")
  pbar = ProgressBar.create(title: "Networks", total: agents.count, autofinish: false, format: '%t %b>> %i| %e')
  agents.find_each do |agent|
    pbar.increment
    graph = Bloodhound::AgentNetwork.new(agent, options[:depth], options[:type])
    graph.build
    graph.write
  end
  pbar.finish
elsif options[:agent_id]
  agent = Agent.find(options[:agent_id])
  puts "Creating network graph for #{agent.fullname} as " + options[:type]
  graph = Bloodhound::AgentNetwork.new(agent, options[:depth], options[:type])
  graph.build
  graph.write
  puts 'Done creating agent network graph'
end