# encoding: utf-8

module Bloodhound
  class AgentWorker
    include Sidekiq::Worker
    sidekiq_options queue: :agent

    def perform(id)
      o = Occurrence.find(id)
      o.recordedByParsed = parse(o.recordedBy).as_json
      o.identifiedByParsed = parse(o.identifiedBy).as_json
      o.save
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