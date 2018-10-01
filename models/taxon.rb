class Taxon < ActiveRecord::Base
  has_many :taxon_determiners
  has_many :determinations, through: :taxon_determiners, source: :agent

  has_many :taxon_occurrences
  has_many :occurrences, through: :taxon_occurrences, source: :occurrence

  def self.enqueue(file_path)
    Sidekiq::Client.enqueue(Bloodhound::TaxonWorker, file_path)
  end

  def self.enqueue_kingdoms(id)
    Sidekiq::Client.enqueue(Bloodhound::KingdomWorker, id)
  end

end