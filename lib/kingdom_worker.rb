# encoding: utf-8

module Bloodhound
  class KingdomWorker
    include Sidekiq::Worker
    sidekiq_options queue: :kingdom

    ACCEPTED_KINGDOMS = ["Animalia", "Plantae", "Fungi", "Protista", "Chromista", "Protozoa"]

    def perform(id)
      t = Taxon.find(id)
      response = RestClient::Request.execute(
        method: :get,
        url: Sinatra::Application.settings.gn_api + 'name_resolvers.json?data_source_ids=11&names=' + URI::encode(t.family),
      )
      results = JSON.parse(response, :symbolize_names => true)
      kingdom = results[:data][0][:results][0][:classification_path].split("|")[0] rescue nil
      if ACCEPTED_KINGDOMS.include?(kingdom)
        t.kingdom = kingdom
        t.save
      end
    end

  end
end