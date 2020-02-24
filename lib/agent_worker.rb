# encoding: utf-8

module Bloodhound
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    REDIS_POOL = ConnectionPool.new(size: 10) { Redis.new(url: ENV['REDIS_URL']) }

    def perform(row)
      agents = parse(row["agents"])

      agents.each do |a|
        given_name = a[:given].to_s.strip
        family_name = a[:family].to_s.strip

        REDIS_POOL.with do |client|
          agent_id = client.get("#{family_name} #{given_name}")
          if !agent_id
            agent_id = Agent.create({family: family_name, given: given_name }).id
            client.set("#{family_name} #{given_name}", agent_id)
          end
          recs = row["gbifIDs_recordedBy"]
                    .tr('[]', '')
                    .split(',')
                    .map{|r| [ r.to_i, agent_id ] }
          ids = row["gbifIDs_identifiedBy"]
                    .tr('[]', '')
                    .split(',')
                    .map{|r| [ r.to_i, agent_id ] }
          if !recs.empty?
            OccurrenceRecorder.import [:occurrence_id, :agent_id], recs, batch_size: 2500, validate: false, on_duplicate_key_ignore: true
          end
          if !ids.empty?
            OccurrenceDeterminer.import [:occurrence_id, :agent_id], ids, batch_size: 2500, validate: false, on_duplicate_key_ignore: true
          end
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
