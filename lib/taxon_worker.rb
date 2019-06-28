# encoding: utf-8

module Bloodhound
  class TaxonWorker
    include Sidekiq::Worker
    sidekiq_options queue: :taxon

    def perform(row)
      taxon = Taxon.create_or_find_by(family: row["family"].strip)
      data = row["gbifIDs_family"].tr('[]', '')
                        .split(',')
                        .map{|r| { occurrence_id: r.to_i, taxon_id: taxon.id } }
      if !data.empty?
        TaxonOccurrence.import data, batch_size: 2500, validate: false, on_duplicate_key_ignore: true
      end
    end

  end
end
