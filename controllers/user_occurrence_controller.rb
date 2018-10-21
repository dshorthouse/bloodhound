# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module UserOccurrenceController

        def self.registered(app)

          app.post '/user-occurrence/bulk.json' do
            protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            occurrence_ids = req[:occurrence_ids].split(",")
            if !visible
              UserOccurrence.where(occurrence_id: occurrence_ids)
                            .where(user_id: @user[:id])
                            .destroy_all
            end
            data = occurrence_ids.map{|o| { 
                user_id: @user[:id],
                occurrence_id: o.to_i,
                action: action,
                visible: visible
              }
            }
            UserOccurrence.create(data)
            { message: "ok" }.to_json
          end

          app.post '/user-occurrence/:occurrence_id.json' do
            protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            action = req[:action] rescue nil
            visible = req[:visible] rescue true
            uo = UserOccurrence.new
            uo.user_id = @user[:id]
            uo.occurrence_id = params[:occurrence_id]
            uo.action = action
            uo.visible = visible
            uo.save
            { message: "ok", id: uo.id }.to_json
          end

          app.put '/user-occurrence/bulk.json' do
            protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            ids = req[:ids].split(",")
            UserOccurrence.where(id: ids, user_id: @user[:id])
                          .update_all({action: req[:action]})
            { message: "ok" }.to_json
          end

          app.put '/user-occurrence/:id.json' do
            protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            uo = UserOccurrence.find_by(id: params[:id], user_id: @user[:id])
            uo.action = req[:action]
            uo.visible = true
            uo.save
            { message: "ok" }.to_json
          end

          app.delete '/user-occurrence/bulk.json' do
            protected!
            content_type "application/json"
            req = JSON.parse(request.body.read).symbolize_keys
            ids = req[:ids].split(",")
            UserOccurrence.where(id: ids, user_id: @user[:id])
                          .delete_all
            { message: "ok" }.to_json
          end

          app.delete '/user-occurrence/:id.json' do
            protected!
            content_type "application/json"
            UserOccurrence.where(id: params[:id], user_id: @user[:id])
                          .delete_all
            { message: "ok" }.to_json
          end

        end

      end
    end
  end
end