# encoding: utf-8

module Bloodhound
  class TaxonWorker
    include Sidekiq::Worker
    sidekiq_options queue: :taxon

    REDIS_POOL = ConnectionPool.new(size: 10) { Redis.new(url: ENV['REDIS_URL']) }

    def perform(row)
      family_name = row["family"].to_s.strip

      REDIS_POOL.with do |client|

        taxon_id = client.get(family_name)
        if !taxon_id
          taxon_id = Taxon.create(family: family_name).id
          client.set(family_name, taxon_id)
        end
        
        data = row["gbifIDs_family"]
                  .tr('[]', '')
                  .split(',')
                  .map{|r| [ r.to_i, taxon_id ] }
        if !data.empty?
          TaxonOccurrence.import [:occurrence_id, :taxon_id],  data, batch_size: 2500, validate: false, on_duplicate_key_ignore: true
        end

      end
    end

  end
end
