# encoding: utf-8

module Bloodhound
  class TaxonWorker

    def initialize(occurrence)
      @o = occurrence
    end

    def process
      if !@o.family.blank?
        taxon = Taxon.find_or_create_by(family: @o.family)
        TaxonOccurrence.create(occurrence_id: @o.id, taxon_id: taxon.id)
        OccurrenceDeterminer.where(occurrence_id: @o.id).pluck(:agent_id).each do |agent_id|
          TaxonDeterminer.create(agent_id: agent_id, taxon_id: taxon.id)
        end
      end
    end

  end
end