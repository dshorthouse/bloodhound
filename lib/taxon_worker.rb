# encoding: utf-8

module Bloodhound
  class TaxonWorker
    include Sidekiq::Worker
    sidekiq_options queue: :taxon

    def perform(id)
      o = Occurrence.find(id)
      job = Bloodhound::TaxonProcessor.new(o)
      job.process
    end

  end
end