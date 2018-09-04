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
            public_profiles
            haml :home
          end

          app.get '/about' do
            haml :about
          end

          app.get '/agent.json' do
            search_agent
            format_agents.to_json
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