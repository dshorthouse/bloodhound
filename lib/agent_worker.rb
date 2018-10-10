# encoding: utf-8

module Bloodhound
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(file_path)
      CSV.foreach(file_path, :headers => true) do |row|
        agents = parse(row["agents"])
        gbifIDs_recordedBy = row["gbifIDs_recordedBy"].tr('[]', '')
                                                      .split(',')
                                                      .map(&:to_i)
        gbifIDs_identifiedBy = row["gbifIDs_identifiedBy"].tr('[]', '')
                                                          .split(',')
                                                          .map(&:to_i)
        agents.each do |a|
          begin
            agent = Agent.find_or_create_by(family: a[:family].to_s, given: a[:given].to_s)
          rescue
            retry
          end
          if !gbifIDs_recordedBy.empty?
            data = gbifIDs_recordedBy.map{|r| {
              occurrence_id: r,
              agent_id: agent.id,
              original_agent_id: agent.id }}
            OccurrenceRecorder.import data
          end
          if !gbifIDs_identifiedBy.empty?
            data = gbifIDs_identifiedBy.map{|r| {
              occurrence_id: r,
              agent_id: agent.id,
              original_agent_id: agent.id }}
            OccurrenceDeterminer.import data
          end
        end
      end
    end

    def parse(raw_names)
      names = []
      DwcAgent.parse(raw_names).each do |r|
        name = DwcAgent.clean(r)
        if !name[:family].nil? && name[:family].length >= 3
          names << name
        end
      end
      names.uniq
    end

  end
end