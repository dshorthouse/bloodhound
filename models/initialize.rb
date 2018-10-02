# encoding: utf-8
require_relative '../concerns/model_utility'

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
          ActiveRecord::Base.send :include, ModelUtility
          require_all 'models'

          ActiveSupport::Inflector.inflections do |inflect|
            inflect.irregular 'taxon', 'taxa'
          end

          app.before { ActiveRecord::Base.verify_active_connections! if ActiveRecord::Base.respond_to?(:verify_active_connections!) }
          app.after { ActiveRecord::Base.clear_active_connections! }
        end

      end
    end
  end
end