# encoding: utf-8

module Bloodhound
  class IO

    class << self

      def csv_stream_occurrences(occurrences)
        Enumerator.new do |y|
          header = ["action"].concat(Occurrence.attribute_names - ["dateIdentified_processed", "eventDate_processed"])
          y << CSV::Row.new(header, header, true).to_s
          if !occurrences.empty?
            occurrences.find_each do |o|
              attributes = o.occurrence.attributes
              attributes.delete("dateIdentified_processed")
              attributes.delete("eventDate_processed")
              data = [o.action].concat(attributes.values)
              y << CSV::Row.new(header, data).to_s
            end
          end
        end
      end

      def csv_stream_candidates(occurrences)
        Enumerator.new do |y|
          header = ["action"].concat(Occurrence.attribute_names - ["dateIdentified_processed", "eventDate_processed"]).concat(["not me"])
          y << CSV::Row.new(header, header, true).to_s
          if !occurrences.empty?
            occurrences.each do |o|
              attributes = o.occurrence.attributes
              attributes.delete("dateIdentified_processed")
              attributes.delete("eventDate_processed")
              data = [""].concat(attributes.values).concat([""])
              y << CSV::Row.new(header, data).to_s
            end
          end
        end
      end

    end

  end
end