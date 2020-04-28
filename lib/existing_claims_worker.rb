# encoding: utf-8

module Bloodhound
  class ExistingClaimsWorker
    include Sidekiq::Worker
    sidekiq_options queue: :existing_claims

    ORCID_REGEX = /(\d{4}-){3}\d{3}[0-9X]{1}/
    WIKI_REGEX = /Q[0-9]{1,}/
    EXTERNAL_USER = 2

    def perform(row)
      recs = row["gbifIDs_recordedBy"]
                .tr('[]', '')
                .split(',')
      ids = row["gbifIDs_identifiedBy"]
                .tr('[]', '')
                .split(',')

      uniq_recs = recs - ids
      uniq_ids = ids - recs
      both = recs & ids

      row["agentIDs"].split("|").each do |id|
        u = get_user(id)
        next if u.nil?
        if !uniq_recs.empty?
          uo = uniq_recs.map{|r| [u.id, r.to_i, "recorded", EXTERNAL_USER]}
          import_user_occurrences(uo)
        end
        if !uniq_ids.empty?
          uo = uniq_ids.map{|r| [u.id, r.to_i, "identified", EXTERNAL_USER]}
          import_user_occurrences(uo)
        end
        if !both.empty?
          uo = both.map{|r| [u.id, r.to_i, "recorded,identified", EXTERNAL_USER]}
          import_user_occurrences(uo)
        end
      end
    end

    def get_user(id)
      user = nil
      wiki = WIKI_REGEX.match(id)
      orcid = ORCID_REGEX.match(id)
      if wiki
        user = User.create_or_find_by({ wikidata: wiki[0] })
        if !user.valid_wikicontent?
          es = ::Bloodhound::ElasticUser.new
          es.delete(user) rescue nil
          user.delete
          user = nil
        end
      elsif orcid
        user = User.create_or_find_by({ orcid: orcid[0] })
      end
      user
    end

    def import_user_occurrences(uo)
      UserOccurrence.import [:user_id, :occurrence_id, :action, :created_by], uo, batch_size: 500, validate: false, on_duplicate_key_ignore: true
    end

  end
end
