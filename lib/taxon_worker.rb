# encoding: utf-8

module Bloodhound
  class TaxonWorker
    include Sidekiq::Worker
    sidekiq_options queue: :taxon

    def perform(row)
      taxon = Taxon.create_or_find_by(family: row["family"].strip)
      occurrence_ids = row["gbifIDs_family"].tr('[]', '').split(',').map(&:to_i)
      data = occurrence_ids.map{|r| { occurrence_id: r, taxon_id: taxon.id}}
      TaxonOccurrence.import data, batch_size: 500, validate: false, on_duplicate_key_ignore: true
    end

  end
end
