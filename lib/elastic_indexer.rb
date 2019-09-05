# encoding: utf-8

module Bloodhound
  class ElasticIndexer

    INDICES = {
      agents: 'bloodhound_agents',
      users: 'bloodhound_users',
      organizations: 'bloodhound_organizations'
    }

    def initialize(opts = {})
      @client = Elasticsearch::Client.new request_timeout: 5*60
      @settings = INDICES.merge(opts)
      @processes = 8
    end

    def delete_agent_index
      if @client.indices.exists index: @settings[:agents]
        @client.indices.delete index: @settings[:agents]
      end
    end

    def delete_user_index
      if @client.indices.exists index: @settings[:users]
        @client.indices.delete index: @settings[:users]
      end
    end

    def delete_organization_index
      if @client.indices.exists index: @settings[:organizations]
        @client.indices.delete index: @settings[:organizations]
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
          agent: {
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
      }
      @client.indices.create index: @settings[:agents], body: config
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
          user: {
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
      }
      @client.indices.create index: @settings[:users], body: config
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
              organization_analyzer: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", :autocomplete]
              },
              institution_codes: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase"]
              }
            }
          }
        },
        mappings: {
          organization: {
            properties: {
              id: { type: 'text', index: false },
              name: {
                type: 'text',
                search_analyzer: :standard,
                analyzer: :organization_analyzer,
                norms: false
              },
              address: {
                type: 'text',
                search_analyzer: :standard,
                analyzer: :organization_analyzer,
                norms: false
              },
              institution_codes: {
                type: 'text',
                analyzer: :institution_codes,
                norms: false
              },
              isni: { type: 'text', index: false },
              ringgold: { type: 'text', index: false },
              grid: { type: 'text', index: false },
              wikidata: { type: 'text', index: false },
              preferred: { type: 'text', index: false }
            }
          }
        }
      }
      @client.indices.create index: @settings[:organizations], body: config
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
      @client.bulk index: @settings[:agents], type: 'agent', refresh: false, body: agents
    end

    def add_agent(a)
      @client.index index: @settings[:agents], type: 'agent', id: a.id, body: agent_document(a)
    end

    def update_agent(a)
      doc = { doc: agent_document(a) }
      @client.update index: @settings[:agents], type: 'agent', id: a.id, body: doc
    end

    def delete_agent(a)
      @client.delete index: @settings[:agents], type: 'agent', id: a.id
    end

    def agent_document(a)
      {
        id: a.id,
        family: a.family,
        given: a.given,
        fullname: a.fullname
      }
    end

    def organization_document(org)
      {
        id: org.identifier,
        name: org.name,
        address: org.address,
        institution_codes: org.institution_codes
      }
    end

    def import_organizations
      Organization.find_in_batches do |batch|
        bulk_organization(batch)
      end
    end

    def add_organization(org)
      @client.index index: @settings[:organizations], type: 'organization', id: org.id, body: organization_document(org)
    end

    def update_organization(org)
      doc = { doc: organization_document(org) }
      @client.update index: @settings[:organizations], type: 'organization', id: org.id, body: doc
    end

    def delete_organization(org)
      @client.delete index: @settings[:organizations], type: 'organization', id: org.id
    end

    def refresh_agent_index
      @client.indices.refresh index: @settings[:agents]
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
      @client.bulk index: @settings[:users], type: 'user', refresh: false, body: users
    end

    def import_users
      User.where.not(family: [nil, ""])
          .where.not(id: User::BOT_IDS)
          .find_in_batches do |batch|
        bulk_user(batch)
      end
    end

    def get_user(u)
      begin
        @client.get index: @settings[:users], type: 'user', id: u.id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end
    end

    def add_user(u)
      @client.index index: @settings[:users], type: 'user', id: u.id, body: user_document(u)
    end

    def update_user(u)
      doc = { doc: user_document(u) }
      @client.update index: @settings[:users], type: 'user', id: u.id, body: doc
    end

    def delete_user(u)
      @client.delete index: @settings[:users], type: 'user', id: u.id
    end

    def user_document(u)
      {
        id: u.id,
        orcid: u.orcid,
        wikidata: u.wikidata,
        family: u.family,
        given: u.given,
        fullname: u.fullname,
        other_names: u.other_names.split("|").map(&:strip)
      }
    end

    def refresh_user_index
      @client.indices.refresh index: @settings[:users]
    end

    def organization_document(o)
      {
        id: o.id,
        name: o.name,
        address: o.address,
        institution_codes: o.institution_codes,
        isni: o.isni,
        grid: o.grid,
        ringgold: o.ringgold,
        wikidata: o.wikidata,
        preferred: o.identifier
      }
    end

    def bulk_organization(batch)
      organizations = []
      batch.each do |o|
        organizations << {
          index: {
            _id: o.id,
            data: organization_document(o)
          }
        }
      end
      @client.bulk index: @settings[:organizations], type: 'organization', refresh: false, body: organizations
    end

    def get_organization(o)
      begin
        @client.get index: @settings[:users], type: 'organization', id: o.id
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end
    end

    def refresh_organization_index
      @client.indices.refresh index: @settings[:organizations]
    end

  end
end
