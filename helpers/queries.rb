# encoding: utf-8

module Sinatra
  module Bloodhound
    module Queries

      def build_name_query(search)
        {
          query: {
            multi_match: {
              query:      search,
              type:       :cross_fields,
              analyzer:   :standard,
              fields:     ["family^3", "given", "*.edge"],
              minimum_should_match: "50%"
            }
          }
        }
      end

      def build_organization_query(search)
        {
          query: {
            multi_match: {
              query: search,
              type: :best_fields,
              fields: ["institution_codes^5", "name^3", "address"]
            }
          }
        }
      end

    end
  end
end