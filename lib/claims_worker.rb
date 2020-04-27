# encoding: utf-8

module Bloodhound
  class ClaimsWorker
    include Sidekiq::Worker
    sidekiq_options queue: :claims

    def perform(row)
      recorders = parse(row["recordedByID"])
      determiners = parse(row["identifiedByID"])
    end

    def parse(raw)
      #TODO: split with other delimiters than pipes?
      #TODO: is it a wikidata or ORCID identifier?
      #TODO: regex match the Q number or ORCID ID to user table
      #TODO: make user when Q number or ORCID ID not known
      #TODO: create claim if it does not already exist, claimant is who?
    end

  end
end
