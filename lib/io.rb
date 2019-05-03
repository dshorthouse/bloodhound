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
          header = ["action"].concat(Occurrence.attribute_names - ["dateIdentified_processed", "eventDate_processed"])
                             .concat(["not me"])
          y << CSV::Row.new(header, header, true).to_s
          if !occurrences.empty?
            occurrences.each do |o|
              attributes = o.occurrence.attributes
              attributes.delete("dateIdentified_processed")
              attributes.delete("eventDate_processed")
              data = [""].concat(attributes.values)
                         .concat([""])
              y << CSV::Row.new(header, data).to_s
            end
          end
        end
      end

      def jsonld_stream(user)
        ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
        id_url = user.orcid ? "https://orcid.org/#{user.orcid}" : "https://www.wikidata.org/wiki/#{user.wikidata}"
        dwc_contexts = Hash[Occurrence.attribute_names.reject {|column| ignore_cols.include?(column)}
                                    .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignore_cols.include?(o) }]
        context = {
          "@vocab": "http://schema.org/",
          identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
          recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
          PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen"
        }.merge(dwc_contexts)

        output = StringIO.open("", "w+")
        w = Oj::StreamWriter.new(output, indent: 1)
        w.push_object()
        w.push_value(context.as_json, "@context")
        w.push_key("@type")
        w.push_value("Person")
        w.push_key("@id")
        w.push_value(id_url)
        w.push_key("givenName")
        w.push_value(user.given)
        w.push_key("familyName")
        w.push_value(user.family)
        w.push_value(user.other_names.split("|"), "alternateName")
        w.push_key("sameAs")
        w.push_value(id_url)
        w.push_object("@reverse")
        w.push_array("identified")
        jsonld_specimens_enum(user, "identifications").each do |o|
          w.push_value(o.as_json)
        end
        w.pop
        w.push_array("recorded")
        jsonld_specimens_enum(user, "recordings").each do |o|
          w.push_value(o.as_json)
        end
        w.pop
        w.pop_all
        output.string()
      end

      def jsonld_specimens_enum(user, type="recordings")
        ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
        Enumerator.new do |y|
          user.send(type).find_each do |o|
            y << { "@type": "PreservedSpecimen",
                   "@id": "https://gbif.org/occurrence/#{o.occurrence.id}",
                   sameAs: "https://gbif.org/occurrence/#{o.occurrence.id}"
                 }.merge(o.occurrence.attributes.reject {|column| ignore_cols.include?(column)})
          end
        end
      end

    end

  end
end