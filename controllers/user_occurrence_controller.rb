# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module UserOccurrenceController

        def self.registered(app)

          app.post '/user-occurrence/bulk.json' do
            protected!
            req = JSON.parse(request.body.read).symbolize_keys
            data = req[:ids].split(",").map{|o| { user_id: @user[:id], occurrence_id: o.to_i }}
            UserOccurrence.create(data)
            { message: "ok" }.to_json
          end

          app.post '/user-occurrence/:occurrence_id.json' do
            protected!
            uo = UserOccurrence.new
            uo.user_id = @user[:id]
            uo.occurrence_id = params[:occurrence_id]
            uo.save
            { message: "ok" }.to_json
          end

          app.delete '/user-occurrence/bulk.json' do
            protected!
            req = JSON.parse(request.body.read).symbolize_keys
            data = req[:ids].split(",")
            UserOccurrence.delete(data)
            { message: "ok" }.to_json
          end

          app.delete '/user-occurrence/:id.json' do
            protected!
            uo = UserOccurrence.find(params[:id])
            uo.destroy
            { message: "ok" }.to_json
          end

        end

      end
    end
  end
end