# encoding: utf-8

module Sinatra
  module Bloodhound
    module Queries

      def build_name_query(search)
        parsed = Namae.parse search
        name = DwcAgent.clean(parsed[0]) rescue { family: nil, given: nil }
        family = !name[:family].nil? ? name[:family] : ""
        given = !name[:given].nil? ? name[:given] : ""
        {
          query: {
            bool: {
              must: [
                match: { "family" => family }
              ],
              should: [
                { match: { "family.edge" => search } },
                { match: { "given.edge" => given } }
              ]
            }
          }
        }
=begin
        {
          query: {
            bool: {
              should: [
                {
                  multi_match: {
                    query:      search,
                    type:       :cross_fields,
                    analyzer:   :standard,
                    fields:     ["given", "family^3"],
                    minimum_should_match: "50%"
                  }
                },
                {
                  multi_match: {
                    query:      search,
                    type:       :cross_fields,
                    analyzer:   :standard,
                    fields:     [ "given.edge", "family.edge^3" ]
                  }
                }
              ]
            }
          }
        }
=end
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