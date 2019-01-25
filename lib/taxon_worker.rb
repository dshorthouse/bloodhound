# encoding: utf-8

module Bloodhound
  class TaxonWorker
    include Sidekiq::Worker
    sidekiq_options queue: :taxon

    def perform(file_path)
      CSV.foreach(file_path, :headers => true) do |row|
        begin
          taxon = Taxon.find_or_create_by(family: row["family"].strip)
        rescue
          retry
        end
        occurrence_ids = row["gbifIDs_family"].tr('[]', '').split(',').map(&:to_i)
        data = occurrence_ids.map{|r| { occurrence_id: r, taxon_id: taxon.id}}
        TaxonOccurrence.import data, batch_size: 500, validate: false
      end
    end

  end
end