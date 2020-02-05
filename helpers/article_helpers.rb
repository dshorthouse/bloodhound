# encoding: utf-8

module Sinatra
  module Bloodhound
    module ArticleHelpers

      def articles
        @pagy, @results = pagy(Article.order(created: :desc))
      end

      def search_article
        searched_term = params[:q]
        @results = []
        return if !searched_term.present?

        page = (params[:page] || 1).to_i

        client = Elasticsearch::Client.new
        body = build_article_query(searched_term)
        from = (page -1) * 30

        response = client.search index: Settings.elastic.article_index, from: from, size: 30, body: body
        results = response["hits"].deep_symbolize_keys

        @pagy = Pagy.new(count: results[:total][:value], items: 30, page: page)
        @results = results[:hits]
      end

    end
  end
end
