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

          app.get '/agent/:id' do
            id = params[:id].to_i
            page = (params[:page] || 1).to_i
            begin
              @agent = Agent.find(id)
              @pagy, @results = pagy(@agent.occurrences, page: page)

              haml :'agents/agent', locals: { active_page: "agents" }
            rescue
              status 404
              haml :oops, locals: { active_page: "agents" }
            end
          end

          app.get '/agents' do
            search_agent
            @formatted_results = format_agents
            @count = Agent.count
            haml :'agents/agents', locals: { active_page: "agents" }
          end

          app.get '/countries' do
            @results = []
            @countries = IsoCountryCodes.for_select.group_by{|u| ActiveSupport::Inflector.transliterate(u[0][0]) }
            haml :'countries/countries', locals: { active_page: "countries" }
          end

          app.get '/country/:country_code' do
            country_code = params[:country_code]
            @results = []
            begin
              @country = IsoCountryCodes.find(country_code)
              users = User.where("country_code LIKE ?", "%#{country_code}%").order(:family)
              @pagy, @results = pagy(users, items: 30)
              haml :'countries/country', locals: { active_page: "countries" }
            rescue
              status 404
              haml :oops
            end
          end

          app.get '/trainers' do
            trainers
            haml :'trainers', locals: { active_page: "trainers" }
          end

          app.get '/developers' do
            file = File.join(root, "public", "data", "bloodhound-public-claims.csv.gz")
            @compressed_file_size = (File.size(file).to_f / 2**20).round(2) rescue nil
            haml :developers
          end

          app.get '/how-it-works' do
            haml :how_it_works
          end

          app.get '/integrations' do
            haml :integrations
          end

          app.get '/get-started' do
            haml :get_started
          end

          app.get '/agent.json' do
            content_type "application/json", charset: 'utf-8'
            search_agent
            format_agents.to_json
          end

          app.get '/user.json' do
            content_type "application/json"
            search_user
            format_users.to_json
          end

          app.get '/user.rss' do
            content_type "application/rss+xml", charset: 'utf-8'
            rss = RSS::Maker.make("2.0") do |maker|
              maker.channel.language = "en"
              maker.channel.author = "Bloodhound"
              maker.channel.updated = Time.now.to_s
              maker.channel.link = "#{Sinatra::Application.settings.base_url}/user.rss"
              maker.channel.title = "Bloodhound New User Feed"
              maker.channel.description = "New User Feed on #{Sinatra::Application.settings.base_url}"

              User.where(is_public: true).where.not(made_public: nil)
                  .where("made_public >= ?", 2.days.ago)
                  .find_each do |user|
                id_statement = nil
                recorded_statement = nil
                statement = nil
                if !user.top_family_identified.nil?
                  id_statement = "identified #{user.top_family_identified}"
                end
                if !user.top_family_recorded.nil?
                  recorded_statement = "collected #{user.top_family_recorded}"
                end
                if !user.top_family_identified.nil? || !user.top_family_recorded.nil?
                  statement = [id_statement,recorded_statement].compact.join(" and ")
                end
                maker.items.new_item do |item|
                  item.link = "#{Sinatra::Application.settings.base_url}/#{user.identifier}"
                  item.title = "#{user.fullname}"
                  item.description = "#{user.fullname} #{statement}"
                  item.updated = user.updated
                end
              end
            end
            rss.to_s
          end

          app.get '/organization.json' do
            content_type "application/json", charset: 'utf-8'
            search_organization
            format_organizations.to_json
          end

          app.get '/occurrence/:id.json' do
            content_type "application/ld+json", charset: 'utf-8'
            ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
            begin
              occurrence = Occurrence.find(params[:id])
              dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| ignore_cols.include?(column)}
                                          .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignore_cols.include?(o) }]
              response = {}
              response["@context"] = {
                  "@vocab": "http://schema.org/",
                  identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
                  recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
                  associatedReferences: "http://rs.tdwg.org/dwc/terms/associatedReferences",
                  PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen",
              }.merge(dwc_contexts)
              response["@type"] = "PreservedSpecimen"
              response["@id"] = "https://gbif.org/occurrence/#{occurrence.id}"
              response["sameAs"] = "https://gbif.org/occurrence/#{occurrence.id}"
              occurrence.attributes
                        .reject{|column| ignore_cols.include?(column)}
                        .map{|k,v| response[k] = v }

              response["recorded"] = occurrence.user_recordings.map{|o|
                id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "https://www.wikidata.org/wiki/#{o.user.wikidata}"
                {
                    "@type": "Person",
                    "@id": id_url,
                    sameAs: id_url,
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
                  }
              }
              response["identified"] = occurrence.user_identifications.map{|o|
                id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "https://www.wikidata.org/wiki/#{o.user.wikidata}"
                {
                    "@type": "Person",
                    "@id": id_url,
                    sameAs: id_url,
                    givenName: "#{o.user.given}",
                    familyName: "#{o.user.family}",
                    alternateName: o.user.other_names.present? ? o.user.other_names.split("|") : []
                  }
              }
              response["associatedReferences"] = occurrence.articles.map{|a| {
                    "@type": "ScholarlyArticle",
                    "@id": "https://doi.org/#{a.doi}",
                    sameAs: "https://doi.org/#{a.doi}",
                    description: a.citation
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

          app.get '/organization/:id/metrics' do
            @year = params[:year] || nil
            organization_metrics
            haml :'organizations/metrics', locals: { active_page: "organizations", active_tab: "organization-metrics" }
          end

          app.get '/organization/:id/citations' do
            begin
              page = (params[:page] || 1).to_i
              @articles = organization_articles
              @pagy, @results = pagy(@articles, page: page)
              haml :'organizations/citations', locals: { active_page: "organizations", active_tab: "organization-articles" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/roster' do
            if params[:q] && params[:q].present?
              search_user
            else
              roster
            end
            haml :roster, locals: { active_page: "roster" }
          end

          app.get '/offline' do
            haml :offline, layout: false
          end

        end

      end
    end
  end
end