class Article < ActiveRecord::Base

  has_many :article_occurrences
  has_many :occurrences, through: :article_occurrences, source: :occurrence
  
  serialize :gbif_dois, Array
  serialize :gbif_downloadkeys, Array

  after_create :make_citation

  def user_specimen_count(user_id)
    article_occurrences.joins(:user_occurrences).where(user_occurrences: { user_id: user_id, visible: true } ).count
  end

  def claimed_specimen_count
    article_occurrences.joins(:user_occurrences)
                       .where(user_occurrences: { visible: true })
                       .count
  end

  private

  def make_citation
    begin
      response = RestClient::Request.execute(
        method: :get,
        headers: { Accept: "text/x-bibliography" },
        url: "https://doi.org/" + URI.escape(doi)
      )
      self.citation = response
      self.save
    rescue
    end
  end

end