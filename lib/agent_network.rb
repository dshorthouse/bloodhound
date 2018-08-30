# encoding: utf-8
require 'rgl/adjacency'
require 'rgl/connected_components'
require 'rgl/dot'

module Bloodhound
  class AgentNetwork

    def initialize(agent, depth = 1, type = "dot")
      @graph = WeightedGraph.new
      @agent = agent
      @agents = []
      @depth = depth
      @type = type
    end

    def build
      if @agent.id != @agent.canonical_id
        @agent = Agent.find(@agent.canonical_id)
      end
      collect_agents([@agent], @depth)
      add_edges
      add_attributes
    end

    def write
      if @graph.size > 2
        if @type == "dot"
          write_dot_file
        else
          write_d3_file
        end
      end
    end

    def collect_agents(agents, depth)
      agents.each do |agent|
        if !@agents.map{|a| a[:agent]}.include? agent
          @agents << { agent: agent, recordings: agent.occurrence_recorders.pluck(:occurrence_id) }
        end
      end
      return if depth.zero?
      agents.each do |agent|
        collect_agents(agent.recordings_with, depth-1)
      end
    end

    def add_edges
      @agents.combination(2).each do |pair|
        add_edge(pair.first, pair.second)
      end
    end

    def add_attributes
      @agents.each do |a|
        options = {}
        if @graph.has_vertex?(a[:agent].fullname)
          options[:id] = a[:agent].id
          options[:given] = a[:agent].given
          options[:family] = a[:agent].family
          if a[:agent].id == @agent.id
            options[:fillcolor] = "#962825"
          end
          @graph.add_vertex_attributes(a[:agent].fullname, options)
        end
      end
    end

    def add_edge(agent1, agent2)
      common = agent1[:recordings] & agent2[:recordings]
      @graph.add_edge(agent1[:agent].fullname, agent2[:agent].fullname, common.size) if common.size > 0
    end

    def write_dot_file
      @graph.write_to_dot_file("public/images/graphs/agents/#{@agent.id}")
    end

    def write_d3_file
      @graph.write_to_d3_file("public/images/graphs/agents/#{@agent.id}")
    end

    def to_vis
      @graph.to_vis_graph
    end

  end
end