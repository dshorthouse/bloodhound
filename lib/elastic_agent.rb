# encoding: utf-8
require_relative "elastic_indexer"

module Bloodhound
  class ElasticAgent

    def initialize(opts = {})
      @client = Elasticsearch::Client.new request_timeout: 5*60
      @settings = { index: 'bloodhound_agents' }.merge(opts)
    end

    def delete_index
      if @client.indices.exists index: @settings[:index]
        @client.indices.delete index: @settings[:index]
      end
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
            family: {
              type: 'text',
              analyzer: :name_part_index,
              norms: false,
              fields: {
                edge: {
                  type: 'text',
                  search_analyzer: :name_part_search,
                  analyzer: :name_part_search,
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
                  search_analyzer: :name_part_search,
                  analyzer: :name_part_search,
                  norms: false,
                }
              }
            },
            fullname: {
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


    def refresh_index
      @client.indices.refresh index: @settings[:index]
    end

    def bulk(batch)
      documents = []
      batch.each do |a|
        documents << {
          index: {
            _id: a.id,
            data: document(a)
          }
        }
      end
      @client.bulk index: @settings[:index], refresh: false, body: documents
    end

    def import
      Agent.find_in_batches do |batch|
        bulk(batch)
      end
    end

    def get(a)
      begin
        @client.get index: @settings[:index], id: a.id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end
    end

    def add(a)
      @client.index index: @settings[:index], id: a.id, body: document(a)
    end

    def update(a)
      doc = { doc: document(a) }
      @client.update index: @settings[:index], id: a.id, body: doc
    end

    def delete(a)
      @client.delete index: @settings[:index], id: a.id
    end

    def document(a)
      {
        id: a.id,
        family: a.family,
        given: a.given,
        fullname: a.fullname
      }
    end

  end
end
