# encoding: utf-8

module Bloodhound
  class ElasticIndexer

    def initialize
      @client = Elasticsearch::Client.new request_timeout: 5*60
      @settings = Sinatra::Application.settings
      @processes = 8
    end

    def delete_agent_index
      if @client.indices.exists index: @settings.elastic_agent_index
        @client.indices.delete index: @settings.elastic_agent_index
      end
    end

    def delete_user_index
      if @client.indices.exists index: @settings.elastic_user_index
        @client.indices.delete index: @settings.elastic_user_index
      end
    end

    def delete_organization_index
      if @client.indices.exists index: @settings.elastic_organization_index
        @client.indices.delete index: @settings.elastic_organization_index
      end
    end

    def create_agent_index
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
              family: { type: 'text', fielddata: true, search_analyzer: :family_search, analyzer: :family_index, omit_norms: true },
              given: { type: 'text', search_analyzer: :given_search, analyzer: :given_index, omit_norms: true }
            }
          }
        }
      }
      @client.indices.create index: @settings.elastic_agent_index, body: config
    end

    def create_user_index
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
          user: {
            properties: {
              id: { type: 'integer', index: false },
              orcid: { type: 'text', index: false },
              family: { type: 'text', fielddata: true, search_analyzer: :family_search, analyzer: :family_index, omit_norms: true },
              given: { type: 'text', search_analyzer: :given_search, analyzer: :given_index, omit_norms: true }
            }
          }
        }
      }
      @client.indices.create index: @settings.elastic_user_index, body: config
    end

    def create_organization_index
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
              organization_index: {
                type: "custom",
                tokenizer: "whitespace",
                filter: ["lowercase", "asciifolding", :autocomplete]
              },
              organization_search: {
                type: "custom",
                tokenizer: "whitespace",
                filter: ["lowercase", "asciifolding", :autocomplete]
              }
            }
          }
        },
        mappings: {
          organization: {
            properties: {
              id: { type: 'text', index: false },
              name: { type: 'text', fielddata: true, search_analyzer: :organization_search, analyzer: :organization_index, omit_norms: true },
              address: { type: 'text', search_analyzer: :organization_search, analyzer: :organization_index, omit_norms: true }
            }
          }
        }
      }
      @client.indices.create index: @settings.elastic_organization_index, body: config
    end

    def import_agents
      Agent.find_in_batches do |batch|
        bulk_agent(batch)
      end
    end

    def bulk_agent(batch)
      agents = []
      batch.each do |a|
        agents << {
          index: {
            _id: a.id,
            data: agent_document(a)
          }
        }
      end
      @client.bulk index: @settings.elastic_agent_index, type: 'agent', refresh: false, body: agents
    end

    def add_agent(a)
      @client.index index: @settings.elastic_agent_index, type: 'agent', id: a.id, body: agent_document(a)
    end

    def update_agent(a)
      doc = { doc: agent_document(a) }
      @client.update index: @settings.elastic_agent_index, type: 'agent', id: a.id, body: doc
    end

    def delete_agent(a)
      @client.delete index: @settings.elastic_agent_index, type: 'agent', id: a.id
    end

    def agent_document(a)
      {
        id: a.id,
        family: a.family,
        given: a.given
      }
    end

    def organization_document(org)
      {
        id: org.identifier,
        name: org.name,
        address: org.address
      }
    end

    def import_organizations
      Organization.find_in_batches do |batch|
        bulk_organization(batch)
      end
    end

    def add_organization(org)
      @client.index index: @settings.elastic_organization_index, type: 'organization', id: org.id, body: organization_document(org)
    end

    def refresh_agent_index
      @client.indices.refresh index: @settings.elastic_agent_index
    end

    def import_users
      User.where.not(family: [nil, ""]).find_in_batches do |batch|
        bulk_user(batch)
      end
    end

    def import_organizations
      Organization.find_each do |org|
        add_organization(org)
      end
    end

    def bulk_user(batch)
      users = []
      batch.each do |u|
        users << {
          index: {
            _id: u.id,
            data: user_document(u)
          }
        }
      end
      @client.bulk index: @settings.elastic_user_index, type: 'user', refresh: false, body: users
    end

    def get_user(u)
      begin
        @client.get index: @settings.elastic_user_index, type: 'user', id: u.id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end
    end

    def add_user(u)
      @client.index index: @settings.elastic_user_index, type: 'user', id: u.id, body: user_document(u)
    end

    def update_user(u)
      doc = { doc: user_document(u) }
      @client.update index: @settings.elastic_user_index, type: 'user', id: u.id, body: doc
    end

    def delete_user(u)
      @client.delete index: @settings.elastic_user_index, type: 'user', id: u.id
    end

    def user_document(u)
      {
        id: u.id,
        orcid: u.orcid,
        family: u.family,
        given: u.given
      }
    end

    def refresh_user_index
      @client.indices.refresh index: @settings.elastic_user_index
    end

    def organization_document(o)
      {
        id: o.identifier,
        name: o.name,
        address: o.address
      }
    end

    def bulk_organization(batch)
      organizations = []
      batch.each do |o|
        organizations << {
          index: {
            _id: o.identifier,
            data: organization_document(o)
          }
        }
      end
      @client.bulk index: @settings.elastic_organization_index, type: 'organization', refresh: false, body: organizations
    end

    def refresh_organization_index
      @client.indices.refresh index: @settings.elastic_organization_index
    end

  end
end