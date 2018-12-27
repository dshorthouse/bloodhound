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
            haml :home, locals: { active_page: "home" }
          end

          app.get '/about' do
            haml :about, locals: { active_page: "about" }
          end

          app.get '/integrations' do
            file = File.join(root, "public", "data", "bloodhound-public-claims.gz")
            @compressed_file_size = (File.size(file).to_f / 2**20).round(2)
            haml :integrations, locals: { active_page: "integrations" }
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

          app.get '/organization.json' do
            content_type "application/json"
            search_organization
            format_organizations.to_json
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
                    alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
                  }
              }
              response["identified"] = occurrence.user_identifications.map{|o| {
                    "@type": "Person",
                    "@id": "https://orcid.org/#{o.user.orcid}",
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
                  }
              }
              response.to_json
            rescue
              status 404
              {}.to_json
            end
          end

          app.get '/organizations' do
            organizations
            haml :'organizations/organizations', locals: { active_page: "organizations" }
          end

          app.get '/organizations/search' do
            search_organization
            haml :'organizations/search', locals: { active_page: "organizations" }
          end

          app.get '/organization/:id' do
            organization
            haml :'organizations/organization', locals: { active_page: "organizations", active_tab: "organization-current" }
          end

          app.get '/organization/:id/past' do
            past_organization
            haml :'organizations/organization', locals: { active_page: "organizations", active_tab: "organization-past" }
          end

          app.get '/roster' do
            roster
            haml :roster, locals: { active_page: "roster" }
          end

        end

      end
    end
  end
end