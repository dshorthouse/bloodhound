# encoding: utf-8

module Sinatra
  module Bloodhound
    module Controller
      module UserController

        def self.registered(app)

          app.get '/:id/specimens.json' do
            content_type "application/ld+json", charset: 'utf-8'
            if !params[:id].is_orcid? && !params[:id].is_wiki_id?
              halt 404, {}.to_json
            end

            viewed_user = find_user(params[:id])
            attachment "#{viewed_user.identifier}.json"
            cache_control :no_cache
            headers.delete("Content-Length")
            begin
              ::Bloodhound::IO.jsonld_stream(viewed_user)
            rescue
              status 404
              {}.to_json
            end
          end

          app.get '/:id/specimens.csv' do
            if !params[:id].is_orcid? && !params[:id].is_wiki_id?
              halt 404, [].to_csv
            end
            begin
              csv_stream_headers
              @viewed_user = find_user(params[:id])
              records = @viewed_user.visible_occurrences
              body ::Bloodhound::IO.csv_stream_occurrences(records)
            rescue
              status 404
            end
          end

          app.get '/:id' do
            check_identifier
            @viewed_user = find_user(params[:id])
            if !@viewed_user
              halt 404, haml(:oops)
            end
            @total = {
              number_identified: @viewed_user.identified_count,
              number_recorded: @viewed_user.recorded_count,
              country_counts: @viewed_user.country_counts
            }
            haml :'public/overview', locals: { active_page: "roster" }
          end

          app.get '/:id/specialties' do
            check_identifier
            @viewed_user = find_user(params[:id])
            check_user_public
            @families_identified = @viewed_user.identified_families
            @families_recorded = @viewed_user.recorded_families
            haml :'public/specialties', locals: { active_page: "roster" }
          end

          app.get '/:id/specimens' do
            check_identifier
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@viewed_user.visible_occurrences.order("occurrences.typeStatus desc"), page: page)
              haml :'public/specimens', locals: { active_page: "roster" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/citations' do
            check_identifier
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@viewed_user.articles_citing_specimens, page: page)
              haml :'public/citations', locals: { active_page: "roster" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/citation/:article_id' do
            check_identifier
            
            @viewed_user = find_user(params[:id])
            check_user_public

            @article = Article.find(params[:article_id])
            if !@article
              halt 404, hamls(:oops)
            end

            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@viewed_user.cited_specimens_by_article(@article.id), page: page)
              haml :'public/citation', locals: { active_page: "roster" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/co-collectors' do
            check_identifier
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@viewed_user.recorded_with, page: page)
              haml :'public/co_collectors', locals: { active_page: "roster", active_tab: "co_collectors" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/identified-for' do
            check_identifier
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@viewed_user.identified_for, page: page)
              haml :'public/identified_for', locals: { active_page: "roster", active_tab: "identified_for" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/identifications-by' do
            check_identifier
            @viewed_user = find_user(params[:id])
            check_user_public

            begin
              page = (params[:page] || 1).to_i
              @pagy, @results = pagy(@viewed_user.identified_by, page: page)
              haml :'public/identifications_by', locals: { active_page: "roster", active_tab: "identifications_by" }
            rescue Pagy::OverflowError
              halt 404, haml(:oops)
            end
          end

          app.get '/:id/deposited-at' do
            check_identifier
            @viewed_user = find_user(params[:id])
            check_user_public
            @recordings_at = @viewed_user.recordings_deposited_at
            @identifications_at = @viewed_user.identifications_deposited_at
            haml :'public/deposited_at', locals: { active_page: "roster" }
          end

          app.get '/:id/comments' do
            check_identifier
            @viewed_user = find_user(params[:id])
            if !@viewed_user.can_comment?
              halt 404, haml(:oops)
            end
            haml :'public/comments', locals: { active_page: "roster"}
          end

          app.get '/:id/progress.json' do
            content_type "application/json"

            viewed_user = find_user(params[:id])
            claimed = viewed_user.all_occurrences_count
            agent_ids = candidate_agents(viewed_user).map{|a| a[:id] }.compact
            unclaimed = occurrences_by_agent_ids(agent_ids).where.not(occurrence_id: viewed_user.user_occurrences.select(:occurrence_id))
                                                           .count
            { claimed: claimed, unclaimed: unclaimed }.to_json
          end

        end

      end
    end
  end
end