class Agent < ActiveRecord::Base
  after_create :set_canonical_id

  has_many :occurrence_determiners, dependent: :destroy
  has_many :determinations, through: :occurrence_determiners, source: :occurrence

  has_many :occurrence_recorders, dependent: :destroy
  has_many :recordings, through: :occurrence_recorders, source: :occurrence

  has_many :taxon_determiners, dependent: :destroy
  has_many :determined_taxa, through: :taxon_determiners, source: :taxon

  has_many :aliases, class_name: "Agent", foreign_key: "canonical_id"
  belongs_to :canonical, class_name: "Agent"

  PARSER = ScientificNameParser.new

  def self.enqueue(file_path)
    Sidekiq::Client.enqueue(Bloodhound::AgentWorker, file_path)
  end

  def fullname
    [given, family].join(" ").strip
  end

  def determinations_institutions
    determinations.pluck(:institutionCode).uniq.compact.reject{ |c| c.empty? }
  end

  def recordings_institutions
    recordings.pluck(:institutionCode).uniq.compact.reject{ |c| c.empty? }
  end

  def determinations_year_range
    years = determinations.pluck(:dateIdentified)
                          .map{ |d| Bloodhound::AgentUtility.valid_year(d) }
                          .compact
                          .minmax rescue [nil,nil]
    years[0] = years[1] if years[0].nil?
    years[1] = years[0] if years[1].nil?
    Range.new(years[0], years[1])
  end

  def recordings_year_range
    years = recordings.pluck(:eventDate)
                      .map{ |d| Bloodhound::AgentUtility.valid_year(d) }
                      .compact
                      .minmax rescue [nil,nil]
    years[0] = years[1] if years[0].nil?
    years[1] = years[0] if years[1].nil?
    Range.new(years[0], years[1])
  end

  def recordings_coordinates
    recordings.map(&:coordinates).uniq.compact
  end

  def recordings_with
    Agent.joins(:occurrence_recorders)
         .where(occurrence_recorders: { occurrence_id: occurrence_recorders.pluck(:occurrence_id) })
         .where.not(occurrence_recorders: { agent_id: id }).uniq
  end

  def identified_taxa
    determinations.pluck(:scientificName).compact.uniq
  end

  def identified_species
    species = identified_taxa.map do |name|
      species_name = nil
      parsed = PARSER.parse(name) rescue nil
      if !parsed.nil? && parsed[:scientificName][:parsed] && parsed[:scientificName][:details][0].has_key?(:species)
        species_name = parsed[:scientificName][:canonical]
      end
      species_name
    end
    species.compact.sort
  end

  def determined_families
    determined_taxa.group_by{|i| i }.map{|k, v| { id: k.id, family: k.family, count: v.size } }.sort_by { |a| a[:family] }
  end

  def refresh_orcid_data
    return if !orcid.present?
    response = RestClient::Request.execute(
      method: :get,
      url: Sinatra::Application.settings.orcid_api_url + orcid,
      headers: { accept: 'application/orcid+json' }
    )
    self.class.parse_profile_orcid_response(self, response)
  end

  def aka
    (
      Agent.where(canonical_id: id).where.not(id: id).pluck(:given, :family) | 
      Agent.where(canonical_id: canonical_id).where.not(id: id).pluck(:given, :family)
    ).map{|a| { family: a[1], given: a[0]}}
  end

  def network
    network = Bloodhound::AgentNetwork.new(self)
    network.build
    network.to_vis
  end

  private

  def set_canonical_id
    self.canonical_id = self.id
    self.save
  end

end