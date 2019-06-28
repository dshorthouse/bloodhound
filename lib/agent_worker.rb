# encoding: utf-8

module Bloodhound
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(row)
      agents = parse(row["agents"])
      gbifIDs_recordedBy = row["gbifIDs_recordedBy"].tr('[]', '')
                                                    .split(',')
                                                    .map(&:to_i)
      gbifIDs_identifiedBy = row["gbifIDs_identifiedBy"].tr('[]', '')
                                                        .split(',')
                                                        .map(&:to_i)

      agents.each do |a|
        agent = Agent.create_or_find_by({
          family: a[:family].to_s,
          given: a[:given].to_s
        })
        if !gbifIDs_recordedBy.empty?
          data = gbifIDs_recordedBy.map{|r| {
            occurrence_id: r,
            agent_id: agent.id }}
          OccurrenceRecorder.import data, batch_size: 2500, validate: false
        end
        if !gbifIDs_identifiedBy.empty?
          data = gbifIDs_identifiedBy.map{|r| {
            occurrence_id: r,
            agent_id: agent.id }}
          OccurrenceDeterminer.import data, batch_size: 2500, validate: false
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
