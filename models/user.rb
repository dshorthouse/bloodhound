class User < ActiveRecord::Base
  has_many :user_occurrences
  has_many :occurrences, through: :user_occurrences, source: :occurrence

  self.per_page = 25

  def is_public?
    is_public
  end

  def fullname
    if !family.nil?
      [given, family].compact.join(" ")
    else
      orcid
    end
  end

  def fullname_reverse
    if !family.nil?
      [family, given].compact.join(", ")
    else
      orcid
    end
  end

  def visible_occurrences
    occurrences.joins(:user_occurrences)
               .where(user_occurrences: { visible: true })
  end

  def visible_user_occurrences
    user_occurrences.where(visible: true)
  end

  def user_occurrence_occurrences
    visible_user_occurrences.map{|u| { user_occurrence_id: u.id, action: u.action }
                            .merge(u.occurrence.attributes.symbolize_keys) }
  end

  def user_occurrence_downloadable
    visible_user_occurrences.map{|u| { action: u.action }
                            .merge(u.occurrence.attributes.symbolize_keys) }
  end

  def identifications
    visible_occurrences.where(qry_identified)
  end

  def recordings
    visible_occurrences.where(qry_recorded)
  end

  def identified_families
    taxon_ids = visible_user_occurrences.where(qry_identified)
                                        .joins(:taxon_occurrence)
                                        .pluck(:taxon_id)
    Hash.new(0).tap{ |h| taxon_ids.each { |f| h[f] += 1 } }
               .transform_keys{ |key| Taxon.find(key).family }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def top_family_identified
    identified_families.first[0] if !identified_families.empty?
  end

  def recorded_families
    taxon_ids = visible_user_occurrences.where(qry_recorded)
                                        .joins(:taxon_occurrence)
                                        .pluck(:taxon_id)
    Hash.new(0).tap{ |h| taxon_ids.each { |f| h[f] += 1 } }
               .transform_keys{ |key| Taxon.find(key).family }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def top_family_recorded
    recorded_families.first[0] if !recorded_families.empty?
  end

  def identifications_recordings
    visible_occurrences.where(qry_identified_recorded)
  end

  def identified_count
    visible_user_occurrences.where(qry_identified)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def recorded_count
    visible_user_occurrences.where(qry_recorded)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def identified_and_recorded_count
    visible_user_occurrences.where(qry_identified_and_recorded)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def identified_or_recorded_count
    visible_user_occurrences.where(qry_identified_or_recorded)
                            .pluck(:occurrence_id)
                            .uniq.count
  end

  def qry_identified
    "user_occurrences.action LIKE '%identified%'"
  end

  def qry_recorded
    "user_occurrences.action LIKE '%recorded%'"
  end

  def qry_identified_and_recorded
    "user_occurrences.action LIKE '%recorded%' AND user_occurrences.action LIKE '%identified%'"
  end

  def qry_identified_or_recorded
    "(user_occurrences.action LIKE '%recorded%' OR user_occurrences.action LIKE '%identified%')"
  end

  def check_changes
    changes = []
    visible_occurrences.each do |o|
      response = gbif_response(o.gbifID)
      if response[:scientificName] != o.scientificName
        changes << { gbifID: o.gbifID, old_name: o.scientificName.dup, new_name: response[:scientificName] }
        o.scientificName = response[:scientificName]
      end
      o.lastChecked = Time.now
      o.save
    end
    notify(changes) if !changes.empty?
  end

  def notify(changes)
    updates = changes.map{|c| "Old name: #{c[:old_name]}, New name: #{c[:new_name]}, See: https://www.gbif.org/occurrence/#{c[:gbifID]}"}.join("\n")
    Pony.options = {
      subject: "Bloodhound Notification: Your specimens have been re-identified",
      body: "Hello #{given} #{family},\n\nAt least one of your specimens have been re-identified and are now being shared under a new scientific name.\n\n#{updates}",
      via: :sendmail,
      via_options: {
        address:              Sinatra::Application.settings.smtp_address,
        port:                 '587',
        enable_starttls_auto: true,
        user_name:            Sinatra::Application.settings.smtp_email,
        password:             Sinatra::Application.settings.smtp_password,
        authentication:      :login,
        domain:              Sinatra::Application.settings.smtp_email.split("@").last
      }
    }
    Pony.mail(to: email, from: Sinatra::Application.settings.smtp_email)
  end

  def gbif_response(occurrence_id)
    response = RestClient::Request.execute(
      method: :get,
      url: Sinatra::Application.settings.gbif_api + 'occurrence/' + occurrence_id.to_s,
    )
    JSON.parse(response, :symbolize_names => true)
  end

end