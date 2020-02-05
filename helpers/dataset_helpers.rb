# encoding: utf-8

module Sinatra
  module Bloodhound
    module DatasetHelpers

      def search_dataset
        searched_term = params[:q]
        @results = []
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new
        body = build_dataset_query(searched_term)
        from = (page -1) * 30

        response = client.search index: Settings.elastic.dataset_index, from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
        @results = results[:hits]
      end

      def datasets
        if params[:order] && Dataset.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
          data = Dataset.order("#{params[:order]} #{params[:sort]}")
        else
          data = Dataset.order(:title)
        end
        @pagy, @results = pagy(data)
      end

      def dataset_users
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt 404
        end
        @pagy, @results = pagy(@dataset.users.order(:family))
      end

      def dataset_agents
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt 404
        end

        @pagy, @results = pagy_array(@dataset.agents.to_a, items: 75)
      end

      def dataset_agents_counts
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt 404
        end

        @pagy, @results = pagy_array(@dataset.agents_occurrence_counts.to_a, items: 75)
      end

      def dataset_stats
        @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
        if @dataset.nil?
          halt {}
        end
        { people: @dataset.users.count }
      end

    end
  end
end
