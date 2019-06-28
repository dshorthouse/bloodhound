# encoding: utf-8

module Bloodhound
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(row)
      agents = parse(row["agents"])
      agents.each do |a|
        agent = Agent.create_or_find_by({
          family: a[:family].to_s,
          given: a[:given].to_s
        })
        recs = row["gbifIDs_recordedBy"]
                  .tr('[]', '')
                  .split(',')
                  .map{|r| { occurrence_id: r.to_i, agent_id: agent.id } }
        ids = row["gbifIDs_identifiedBy"]
                  .tr('[]', '')
                  .split(',')
                  .map{|r| { occurrence_id: r.to_i, agent_id: agent.id } }
        if !recs.empty?
          OccurrenceRecorder.import recs, batch_size: 2500, validate: false
        end
        if !ids.empty?
          OccurrenceDeterminer.import ids, batch_size: 2500, validate: false
        end
      end
    end

    def parse(raw)
      agents = []
      DwcAgent.parse(raw).each do |n|
        agent = DwcAgent.clean(n)
        if !agent[:family].nil? && agent[:family].length >= 2
          agents << agent
        end
      end
      agents.uniq
    end

  end
end
