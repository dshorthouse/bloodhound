# encoding: utf-8

module Bloodhound
  class ClusterWorker
    include Sidekiq::Worker
    sidekiq_options queue: :cluster

    def perform(id)
      @agent = Agent.find(id)
      add_edges
    end

    def add_edges
      nodes = []
      agents = @agent.agents_same_family_first_initial
      agents.find_each do |a|
        nodes << AgentNode.create({agent_id: a.id, family: a.family, given: a.given})
      end
      nodes.combination(2).each do |pair|
        w = weight(pair.first.given, pair.second.given)
        if w > 0
          AgentEdge.create(from_node: pair.first, to_node: pair.second, weight: w)
        end
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