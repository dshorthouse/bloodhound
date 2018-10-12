# encoding: utf-8
require 'rgl/adjacency'
require 'rgl/connected_components'
require 'rgl/dot'

module Bloodhound
  class DisambiguateWorker
    include Sidekiq::Worker
    sidekiq_options queue: :disambiguate

    def perform(opts)
      @graph = WeightedGraph.new
      @agent = Agent.find(opts["id"])
      add_edges
      add_attributes
      boost_weights
      if opts["write_graphics"]
        write_graphic_file
      end
    end

    def add_edges
      agents = @agent.agents_same_family_first_initial
      agents.to_a.combination(2).each do |pair|
        w = weight(pair.first.given, pair.second.given)
        if w > 0
          vertex1 = { id: pair.first.id, given: pair.first.given }
          vertex2 = { id: pair.second.id, given: pair.second.given }
          @graph.add_edge(vertex1, vertex2, w)
        end
      end
    end

    def add_attributes
      @graph.vertices.each do |v|
        a = Agent.find(v[:id])
        attributes = {
          collected_with: a.recordings_with.map(&:family),
          determined_families: a.determined_families,
          recordings_year_range: a.recordings_year_range
        }
        @graph.add_vertex_attributes(v, attributes)
      end
    end

    def boost_weights
      @graph.edges.each do |edge|
        agent1 = @graph.vertex_attributes(edge.source)
        agent2 = @graph.vertex_attributes(edge.target)

        weight = edge.weight

        shared_friends = agent1[:collected_with] & agent2[:collected_with]
        if shared_friends.size > 0
          weight += 1
        end

        shared_families = agent1[:determined_families] & agent2[:determined_families]
        if shared_families.size > 0
          weight += 0.5
        end

        edge.set_weight weight
      end
    end

    def write_graphic_file
      if !@graph.empty?
        @graph.write_to_graphic_file("png", "public/images/graphs/#{@agent.family}")
      end
    end

    def weight(given1, given2)
      given1_parts = given1.gsub(/\.\s+/,".").split(/[\.\s]/)
      given2_parts = given2.gsub(/\.\s+/,".").split(/[\.\s]/)
      largest = [given1_parts,given2_parts].max
      smallest = [given1_parts,given2_parts].min

      score = 0
      largest.each_with_index do |val,index|
        if smallest[index]
          if val[0] == smallest[index][0]
            score += 1
          else
            return 0
          end
          if val.length > 1 && smallest[index].length > 1 && val != smallest[index]
            return 0
          end
        else
          score += 0.1
        end
      end
      
      score
    end

  end
end