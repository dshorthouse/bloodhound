# encoding: utf-8

module Bloodhound
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(id)
      o = Occurrence.find(id)
      job = Bloodhound::AgentProcessor.new(o)
      job.process
    end

  end
end