# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module AdminController

        def self.registered(app)

          app.get '/admin/users' do
            admin_protected!
            admin_roster
            haml :'admin/roster'
          end

          app.get '/admin/user/:orcid' do
            admin_protected!
            if params[:orcid].is_orcid?
              @admin_user = User.find_by_orcid(params[:orcid])
              @page = (params[:page] || 1).to_i
              search_size = (params[:per] || 25).to_i
              @total = @admin_user.visible_occurrences.count

              if @page*search_size > @total
                @page = @total/search_size.to_i + 1
              end

              @results = @admin_user.visible_occurrences
                                    .order("occurrences.typeStatus desc")
                                    .paginate(page: @page, per_page: search_size)
              haml :'admin/profile'
            else
              status 404
              haml :oops
            end

          end

          app.get '/admin/user/:orcid/specimens.json' do
            admin_protected!
            if params[:orcid].is_orcid?
              begin
                user = User.find_by_orcid(params[:orcid])
                dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| column == 'gbifID'}
                                            .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if o != "gbifID" }]
                {
                  "@context": {
                    "@vocab": "http://schema.org/",
                    identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                    recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                    Occurrence: "http://rs.tdwg.org/dwc/terms/Occurrence"
                  }.merge(dwc_contexts),
                  "@type": "Person",
                  "@id": "https://orcid.org/#{user.orcid}",
                  givenName: user.given,
                  familyName: user.family,
                  alternateName: user.other_names.split("|"),
                  "@reverse": {
                    identified: user.identifications_enum,
                    recorded: user.recordings_enum
                  }
                }.to_json
              rescue
                status 404
                {}.to_json
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/admin/user/:orcid/specimens.csv' do
            admin_protected!
            if params[:orcid].is_orcid?
              content_type "application/csv"
              attachment   "#{params[:orcid]}.csv"
              user = User.find_by_orcid(params[:orcid])
              records = user.visible_occurrences
              CSV.generate do |csv|
                csv << ["action"].concat(Occurrence.attribute_names)
                records.find_each { |r| csv << [r.action].concat(r.occurrence.attributes.values) }
              end
            else
              status 404
              haml :oops
            end
          end

          app.get '/admin/user/:orcid/support' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])

            @page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i
            @total = @admin_user.claims_received.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @results = @admin_user.claims_received
                                  .paginate(page: @page, per_page: search_size)
            haml :'admin/support'
          end

          app.get '/admin/user/:orcid/candidates' do
            admin_protected!
            if params[:orcid].is_orcid?
              occurrence_ids = []
              @page = (params[:page] || 1).to_i
              @search_size = (params[:per] || 25).to_i

              @admin_user = User.find_by_orcid(params[:orcid])

              if @admin_user.family.nil?
                @results = []
                @total = nil
              else
                agents = search_agents(@admin_user.family, @admin_user.given)

                if !@admin_user.other_names.nil?
                  @admin_user.other_names.split("|").each do |other_name|
                    begin
                      parsed = Namae.parse other_name.gsub(/\./, ".\s")
                      name = DwcAgent.clean(parsed[0])
                      family = !name[:family].nil? ? name[:family] : ""
                      given = !name[:given].nil? ? name[:given] : ""
                      if !family.blank?
                        agents.concat search_agents(family, given)
                      end
                    rescue
                    end
                  end
                end

                id_scores = agents.compact.uniq
                                          .map{|a| { id: a[:id], score: a[:score] }}

                if !id_scores.empty?
                  ids = id_scores.map{|a| a[:id]}
                  nodes = AgentNode.where(agent_id: ids)
                  if !nodes.empty?
                    (nodes.map(&:agent_id) - ids).each do |id|
                      id_scores << { id: id, score: 1 } #TODO: how to more effectively use the edge weights here?
                    end
                  end
                  occurrence_ids = occurrences_by_score(id_scores, @admin_user.id)
                end

                specimen_pager(occurrence_ids)
              end

              haml :'admin/candidates'
            else
              status 404
              haml :oops
            end

          end

          app.get '/admin/user/:orcid/ignored' do
            admin_protected!
            @admin_user = User.find_by_orcid(params[:orcid])
            @page = (params[:page] || 1).to_i
            search_size = (params[:per] || 25).to_i
            @total = @admin_user.hidden_occurrences.count

            if @page*search_size > @total
              @page = @total/search_size.to_i + 1
            end

            @results = @admin_user.hidden_occurrences
                                  .paginate(page: @page, per_page: search_size)
            haml :'admin/ignored'
          end

          app.post '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            occurrence_ids = req[:occurrence_ids].split(",")
            if !visible
              UserOccurrence.where(occurrence_id: occurrence_ids)
                            .where(user_id: req[:user_id].to_i)
                            .destroy_all
            end
            data = occurrence_ids.map{|o| { 
                user_id: req[:user_id].to_i,
                occurrence_id: o.to_i,
                created_by: @user[:id],
                action: action,
                visible: visible
              }
            }
            UserOccurrence.import data, batch_size: 100, validate: false
            { message: "ok" }.to_json
          end

          app.post '/admin/user-occurrence/:occurrence_id.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            uo = UserOccurrence.new
            uo.user_id = req[:user_id].to_i
            uo.occurrence_id = params[:occurrence_id].to_i
            uo.created_by = @user[:id].to_i
            uo.action = action
            uo.visible = visible
            uo.save
            { message: "ok", id: uo.id }.to_json
          end

          app.put '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            occurrence_ids = req[:occurrence_ids].split(",")
            UserOccurrence.where(id: occurrence_ids, user_id: req[:user_id].to_i)
                          .update_all({action: req[:action]})
            { message: "ok" }.to_json
          end

          app.put '/admin/user-occurrence/:id.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find_by(id: params[:id].to_i, user_id: req[:user_id].to_i)
            uo.action = req[:action]
            uo.visible = true
            uo.save
            { message: "ok" }.to_json
          end

          app.delete '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            ids = req[:ids].split(",")
            UserOccurrence.where(id: ids, user_id: req[:user_id].to_i)
                          .delete_all
            { message: "ok" }.to_json
          end

          app.delete '/admin/user-occurrence/:id.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            UserOccurrence.where(id: params[:id].to_i, user_id: req[:user_id].to_i)
                          .delete_all
            { message: "ok" }.to_json
          end

          app.get '/admin/orcid-refresh.json' do
            admin_protected!
            content_type "application/json"
            user = User.find(params[:user_id].to_i)
            user.update_orcid_profile
            cache_clear "fragments/#{user.orcid}"
            { message: "ok" }.to_json
          end

          app.put '/admin/profile.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            user = User.find(params[:user_id].to_i)
            user.is_public = req[:is_public]
            user.save
            update_session
            { message: "ok"}.to_json
          end

        end

      end
    end
  end
end