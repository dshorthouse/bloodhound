# encoding: utf-8

module Bloodhound
  class AgentWorker

    def initialize(occurrence)
      @o = occurrence
    end

    def process
      recorders = parse(@o.recordedBy)
      identifiers = parse(@o.identifiedBy)

      (recorders + identifiers).uniq.each do |a|
        agent = Agent.find_or_create_by(family: a[:family].to_s, given: a[:given].to_s)
        if recorders.include? a
          OccurrenceRecorder.create(occurrence_id: @o.id, agent_id: agent.id)
        end
        if identifiers.include? a
          OccurrenceDeterminer.create(occurrence_id: @o.id, agent_id: agent.id)
        end
      end
    end

    def parse(raw_names)
      names = []
      Bloodhound::AgentUtility.parse(raw_names).each do |r|
        name = Bloodhound::AgentUtility.clean(r)
        if !name[:family].nil? && name[:family].length >= 3
          names << name
        end
      end
      names.uniq
    end

  end
end