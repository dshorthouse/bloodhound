class Agent < ActiveRecord::Base

  has_many :occurrence_determiners, dependent: :delete_all
  has_many :determinations, through: :occurrence_determiners, source: :occurrence

  has_many :occurrence_recorders, dependent: :delete_all
  has_many :recordings, through: :occurrence_recorders, source: :occurrence

  has_many :taxon_determiners, dependent: :delete_all
  has_many :determined_taxa, through: :taxon_determiners, source: :taxon

  def self.enqueue(file_path)
    CSV.foreach(file_path, :headers => true) do |row|
      Sidekiq::Client.enqueue(Bloodhound::AgentWorker, row)
    end
  end

  def fullname
    [given, family].join(" ").strip
  end

  def agents_same_family
    Agent.where(family: family)
  end

  def agents_same_family_first_initial
    agents_same_family.where("LOWER(LEFT(given,1)) = '#{given[0].downcase}'") rescue []
  end

  def processed?
    processed
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
    years = recordings.pluck(:eventDate, :year)
                      .map{ |d| Bloodhound::AgentUtility.valid_year(d.compact.reject(&:empty?).first) }
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
    colleagues = Set.new
    occurrence_recorders.pluck(:occurrence_id).in_groups_of(500, false).each do |group|
      agents = Agent.joins(:occurrence_recorders)
                    .where(occurrence_recorders: { occurrence_id: group }).uniq
      colleagues.merge(agents)
    end
    colleagues.delete(self)
  end

  def identified_taxa
    determinations.pluck(:scientificName).compact.uniq
  end

  def determined_families_counts
    determined_taxa.group_by{|i| i }
                   .map{|k, v| { id: k.id, family: k.family, count: v.size } }
                   .sort_by { |a| a[:family] }
  end

  def determined_families
    determined_taxa.uniq.pluck(:family)
  end

  def occurrences
    recordings.union_all(determinations)
  end

end
