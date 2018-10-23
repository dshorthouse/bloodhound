# encoding: utf-8
require 'neo4j/core/cypher_session/adaptors/http'

module Sinatra
  module Bloodhound
    module Model
      module Initialize

        def self.registered(app)
          ActiveRecord::Base.establish_connection(
            adapter: app.settings.adapter,
            database: app.settings.database,
            host: app.settings.host,
            username: app.settings.username,
            password: app.settings.password,
            reconnect: app.settings.reconnect,
            pool: app.settings.pool,
            timeout: app.settings.timeout
          )

          ActiveSupport::Inflector.inflections do |inflect|
            inflect.irregular 'taxon', 'taxa'
            inflect.irregular 'specimen', 'specimens'
          end

          username = app.settings.neo4j_username
          password = app.settings.neo4j_password
          neo4j_adaptor = Neo4j::Core::CypherSession::Adaptors::HTTP.new("http://#{username}:#{password}@localhost:7474")
          Neo4j::ActiveBase.on_establish_session { Neo4j::Core::CypherSession.new(neo4j_adaptor) }

          app.before { ActiveRecord::Base.verify_active_connections! if ActiveRecord::Base.respond_to?(:verify_active_connections!) }
          app.after { ActiveRecord::Base.clear_active_connections! }
        end

      end
    end
  end
end