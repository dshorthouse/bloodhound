class Taxon < ActiveRecord::Base
  has_many :taxon_determiners
  has_many :determinations, through: :taxon_determiners, source: :agent

  has_many :taxon_occurrences
  has_many :occurrences, through: :taxon_occurrences, source: :occurrence

  def self.enqueue(file_path)
    Sidekiq::Client.enqueue(Bloodhound::TaxonWorker, file_path)
  end

  #TODO: convert to sidekiq queue
  def self.populate_kingdoms
    accepted = ["Animalia", "Plantae", "Fungi", "Protista", "Chromista", "Protozoa"]
    taxa = Taxon.where(kingdom: nil)
    pbar = ProgressBar.create(title: "Kingdoms", total: taxa.count, autofinish: false, format: '%t %b>> %i| %e')
    taxa.find_each do |t|
      response = RestClient::Request.execute(
        method: :get,
        url: Sinatra::Application.settings.gn_api + 'name_resolvers.json?data_source_ids=11&names=' + URI::encode(t.family),
      )
      results = JSON.parse(response, :symbolize_names => true)
      kingdom = results[:data][0][:results][0][:classification_path].split("|")[0] rescue nil
      if accepted.include?(kingdom)
        t.kingdom = kingdom
        t.save
      end
      pbar.increment
    end
    pbar.finish
  end

end