# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module ApplicationController

        def self.registered(app)

          app.before do
            set_session
          end

          app.get '/' do
            example_profiles
            haml :home
          end

          app.get '/about' do
            haml :about
          end

          app.get '/agent.json' do
            content_type "application/json"
            search_agent
            format_agents.to_json
          end

          app.get '/occurrence/:id.json' do
            content_type "application/json"
            occurrence = Occurrence.find(params[:id])
            response = occurrence.attributes
                                 .symbolize_keys
                                 .as_json(except: :lastChecked)
            response[:actions] = occurrence.actions
            response.to_json
          end

          app.get '/roster' do
            roster
            haml :roster
          end

          app.not_found do
            status 404
            haml :oops
          end

        end

      end
    end
  end
end