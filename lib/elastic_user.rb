# encoding: utf-8
require_relative "elastic_indexer"

module Bloodhound
  class ElasticUser < ElasticIndexer

    def initialize(opts = {})
      super
      @settings = { index: 'bloodhound_users' }.merge(opts)
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
              name_part_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding"]
              },
              name_part_search: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", :autocomplete]
              },
              fullname_index: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding"]
              },
              fullname_search: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", :autocomplete]
              }
            }
          }
        },
        mappings: {
          properties: {
            id: { type: 'integer', index: false },
            orcid: { type: 'text', index: false },
            wikidata: { type: 'text', index: false },
            family: {
              type: 'text',
              analyzer: :name_part_index,
              norms: false,
              fields: {
                edge: {
                  type: 'text',
                  analyzer: :name_part_search,
                  search_analyzer: :name_part_search,
                  norms: false,
                }
              }
            },
            given: {
              type: 'text',
              analyzer: :name_part_index,
              norms: false,
              fields: {
                edge: {
                  type: 'text',
                  analyzer: :name_part_search,
                  search_analyzer: :name_part_search,
                  norms: false,
                }
              }
            },
            fullname: {
              type: 'text',
              analyzer: :fullname_index,
              search_analyzer: :fullname_search,
              norms: false
            },
            other_names: {
              type: 'text',
              analyzer: :fullname_index,
              search_analyzer: :fullname_search,
              norms: false
            }
          }
        }
      }
      @client.indices.create index: @settings[:index], body: config
    end

    def import
      User.where.not(family: [nil, ""])
          .where.not(id: User::BOT_IDS)
          .find_in_batches do |batch|
        bulk(batch)
      end
    end

    def document(u)
      {
        id: u.id,
        orcid: u.orcid,
        wikidata: u.wikidata,
        family: u.family,
        given: u.given,
        fullname: u.fullname,
        fullname_reverse: u.fullname_reverse,
        other_names: u.other_names.split("|").map(&:strip)
      }
    end

  end
end
