# encoding: utf-8
require_relative "elastic_indexer"

module Bloodhound
  class ElasticArticle < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: Settings.elastic.article_index }.merge(opts)
    end

    def create_index
      config = {
        settings: {
          analysis: {
            filter: {
              autocomplete: {
                type: "edgeNGram",
                side: "front",
                min_gram: 1,
                max_gram: 50
              },
            },
            analyzer: {
              paper_analyzer: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", :autocomplete]
              }
            }
          }
        },
        mappings: {
          properties: {
            id: { type: 'text', index: false },
            doi: { type: 'text', index: false },
            citation: {
              type: 'text',
              search_analyzer: :standard,
              analyzer: :paper_analyzer,
              norms: false
            },
            abstract: {
              type: 'text',
              analyzer: :standard,
              norms: false
            }
          }
        }
      }
      @client.indices.create index: @settings[:index], body: config
    end

    def import
      Article.find_in_batches do |batch|
        bulk(batch)
      end
    end

    def document(d)
      {
        id: d.id,
        doi: d.doi,
        citation: d.citation,
        abstract: d.abstract
      }
    end

  end
end
