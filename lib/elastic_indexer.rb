# encoding: utf-8

module Bloodhound
  class ElasticIndexer

    def initialize
      @client = Elasticsearch::Client.new request_timeout: 5*60
      @settings = Sinatra::Application.settings
      @processes = 8
    end

    def delete
      if @client.indices.exists index: @settings.elastic_index
        @client.indices.delete index: @settings.elastic_index
      end
    end

    def delete_agents
      puts "Deleting all agents..."
      delete_docs_by_type({type: "agent"})
    end

    def delete_docs_by_type(hsh = {})
      client = Elasticsearch::Client.new url: @settings.elastic_server
      client.perform_request 'POST', @settings.elastic_index + "/#{hsh[:type]}/_delete_by_query", {}, { query: { match_all: {} } }
    end

    def create
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
              family_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding"]
              },
              family_search: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding"]
              },
              given_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", :autocomplete]
              },
              given_search: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", :autocomplete]
              }
            }
          }
        },
        mappings: {
          agent: {
            properties: {
              id: { type: 'integer', index: false },
              canonical_id: { type: 'text', index: false },
              orcid: { type: 'text', index: false },
              family: { type: 'text', fielddata: true, search_analyzer: :family_search, analyzer: :family_index, omit_norms: true },
              given: { type: 'text', search_analyzer: :given_search, analyzer: :given_index, omit_norms: true }
            }
          }
        }
      }
      @client.indices.create index: @settings.elastic_index, body: config
    end

    def import_agents
      agents = Agent.where("id = canonical_id").pluck(:id)
      Parallel.map(agents.in_groups_of(10_000, false), progress: "Search-Agents") do |batch|
        bulk_agent(batch)
      end
    end

    def bulk_agent(batch)
      agents = []
      batch.each do |a|
        agents << {
          index: {
            _id: a,
            data: agent_document(Agent.find(a))
          }
        }
      end
      @client.bulk index: @settings.elastic_index, type: 'agent', refresh: false, body: agents
    end

    def add_agent(a)
      @client.index index: @settings.elastic_index, type: 'agent', id: a.id, body: agent_document(a)
    end

    def update_agent(a)
      doc = { doc: agent_document(a) }
      @client.update index: @settings.elastic_index, type: 'agent', id: a.id, body: doc
    end

    def delete_agent(a)
      @client.delete index: @settings.elastic_index, type: 'agent', id: a.id
    end

    def agent_document(a)
      {
        id: a.id,
        canonical_id: a.canonical_id,
        family: a.family,
        given: a.given
      }
    end

    def refresh
      @client.indices.refresh index: @settings.elastic_index
    end

  end
end