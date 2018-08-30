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
            if authorized?
              page = (params[:page] || 1).to_i
              search_size = (params[:per] || 25).to_i
              occurrences = User.find(@user[:id]).user_occurrence_occurrences

              @total = occurrences.length

              @results = WillPaginate::Collection.create(page, search_size, occurrences.length) do |pager|
                pager.replace occurrences[pager.offset, pager.per_page]
              end
            end
            haml :home
          end

          app.get '/about' do
            haml :about
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