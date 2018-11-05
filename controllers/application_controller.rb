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

          app.get '/user.json' do
            content_type "application/json"
            search_user
            format_users.to_json
          end

          app.get '/occurrence/:id.json' do
            content_type "application/ld+json"
            begin
              occurrence = Occurrence.find(params[:id])
              dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| column == 'gbifID'}
                                          .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if o != "gbifID" }]
              response = {}
              response["@context"] = {
                  "@vocab": "http://schema.org/",
                  identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                  recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                  Occurrence: "http://rs.tdwg.org/dwc/terms/Occurrence"
              }.merge(dwc_contexts)
              response["@type"] = "Occurrence"
              response["@id"] = "https://gbif.org/occurrence/#{occurrence.id}"
              occurrence.attributes
                        .reject{|column| column == 'gbifID'}
                        .map{|k,v| response[k] = v }

              response["recorded"] = occurrence.user_recordings.map{|o| { 
                    "@type": "Person",
                    "@id": "https://orcid.org/#{o.user.orcid}",
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.split("|")
                  }
              }
              response["identified"] = occurrence.user_identifications.map{|o| { 
                    "@type": "Person",
                    "@id": "https://orcid.org/#{o.user.orcid}",
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.split("|")
                  }
              }
              response.to_json
            rescue
              status 404
              {}.to_json
            end
          end

          app.get '/roster' do
            roster
            haml :roster
          end

        end

      end
    end
  end
end