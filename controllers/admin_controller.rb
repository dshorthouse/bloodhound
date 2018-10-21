# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module AdminController

        def self.registered(app)

          app.get '/admin/users' do
            admin_protected!
            all_users
            haml :admin_roster
          end

          app.get '/admin/user/:id' do
            admin_protected!

            @page = (params[:page] || 1).to_i
            @search_size = (params[:per] || 25).to_i
            @admin_user = User.find(params[:id])
            occurrences = @admin_user.user_occurrence_occurrences

            @total = occurrences.length

            @results = WillPaginate::Collection.create(@page, @search_size, occurrences.length) do |pager|
              pager.replace occurrences[pager.offset, pager.per_page]
            end
            haml :admin_profile
          end

          app.get '/admin/candidates/:id' do
            admin_protected!
            occurrence_ids = []
            @page = (params[:page] || 1).to_i
            @search_size = (params[:per] || 25).to_i

            @admin_user = User.find(params[:id])

            if @admin_user.family.nil?
              @results = []
              @total = nil
            else
              agents = search_agents(@admin_user.family, @admin_user.given)

              if !@admin_user.other_names.nil?
                @admin_user.other_names.split("|").each do |other_name|
                  parsed = Namae.parse other_name
                  name = DwcAgent.clean(parsed[0])
                  family = !name[:family].nil? ? name[:family] : nil
                  given = !name[:given].nil? ? name[:given] : nil
                  if !family.nil?
                    agents.concat search_agents(family, given)
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

            haml :admin_candidates
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
                action: action,
                visible: visible
              }
            }
            UserOccurrence.create(data)
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
            uo.action = action
            uo.visible = visible
            uo.save
            { message: "ok", id: uo.id }.to_json
          end

          app.put '/admin/user-occurrence/bulk.json' do
            admin_protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            ids = req[:ids].split(",")
            UserOccurrence.where(id: ids, user_id: req[:user_id].to_i)
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
            data = get_orcid_profile(user.orcid)
            given = data[:person][:name][:"given-names"][:value] rescue nil
            family = data[:person][:name][:"family-name"][:value] rescue nil
            email = nil
            data[:person][:emails][:email].each do |mail|
              next if !mail[:primary]
              email = mail[:email]
            end
            other_names = data[:person][:"other-names"][:"other-name"].map{|n| n[:content]}.join("|") rescue nil
            country_code = data[:person][:addresses][:address][0][:country][:value] rescue nil
            country = IsoCountryCodes.find(country_code).name rescue nil
            user.update({
              family: family,
              given: given,
              email: email,
              other_names: other_names,
              country: country,
              updated: Time.now
            })
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