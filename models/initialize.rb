# encoding: utf-8
require 'neo4j/core/cypher_session/adaptors/http'

module Sinatra
  module Bloodhound
    module Model
      module Initialize

        def self.registered(app)
          ActiveRecord::Base.establish_connection(
            adapter: Settings.adapter,
            database: Settings.database,
            host: Settings.host,
            username: Settings.username,
            password: Settings.password,
            reconnect: Settings.reconnect,
            pool: Settings.pool,
            timeout: Settings.timeout
          )

          if app.settings.environment == :development
            ActiveRecord::Base.logger = Logger.new(STDOUT)
          end

          ActiveSupport::Inflector.inflections do |inflect|
            inflect.irregular 'taxon', 'taxa'
            inflect.irregular 'specimen', 'specimens'
          end

          username = Settings.neo4j_username
          password = Settings.neo4j_password
          neo4j_adaptor = Neo4j::Core::CypherSession::Adaptors::HTTP.new("http://#{username}:#{password}@localhost:7474")
          Neo4j::ActiveBase.on_establish_session { Neo4j::Core::CypherSession.new(neo4j_adaptor) }

          app.before { ActiveRecord::Base.verify_active_connections! if ActiveRecord::Base.respond_to?(:verify_active_connections!) }
          app.after { ActiveRecord::Base.clear_active_connections! }
        end

      end
    end
  end
end