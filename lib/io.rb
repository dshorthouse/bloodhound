# encoding: utf-8

module Bloodhound
  class IO

    include Pagy::Backend

    def initialize(args = {})
      args = defaults.merge(args)
      @user = args[:user]
      @params = args[:params]
      @request = args[:request]
    end

    def defaults
      { user: nil, params: {}, request: {} }
    end

    def base_url
      "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
    end

    def ignored_columns
      ["dateIdentified_processed", "eventDate_processed", "hasImage"]
    end

    def params
      @params
    end

    def request
      @request
    end

    def csv_stream_agent_occurrences(occurrences)
      Enumerator.new do |y|
        header = Occurrence.attribute_names - ignored_columns
        y << CSV::Row.new(header, header, true).to_s
        if !occurrences.empty?
          occurrences.find_each do |o|
            attributes = o.attributes
            ignored_columns.each do |col|
              attributes.delete(col)
            end
            data = attributes.values
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def csv_stream_occurrences(occurrences)
      Enumerator.new do |y|
        header = ["action"].concat(Occurrence.attribute_names - ignored_columns)
        y << CSV::Row.new(header, header, true).to_s
        if !occurrences.empty?
          occurrences.find_each do |o|
            attributes = o.occurrence.attributes
            ignored_columns.each do |col|
              attributes.delete(col)
            end
            data = [o.action].concat(attributes.values)
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def csv_stream_candidates(occurrences)
      Enumerator.new do |y|
        header = ["action"].concat(Occurrence.attribute_names - ignored_columns)
                           .concat(["not me"])
        y << CSV::Row.new(header, header, true).to_s
        if !occurrences.empty?
          occurrences.each do |o|
            attributes = o.occurrence.attributes
            ignored_columns.each do |col|
              attributes.delete(col)
            end
            data = [""].concat(attributes.values)
                       .concat([""])
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def jsonld_stream
      ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
      dwc_contexts = Hash[Occurrence.attribute_names
                                    .reject {|column| ignore_cols.include?(column)}
                                    .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignore_cols.include?(o)}]
      context = {
        "@vocab": "http://schema.org/",
        identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
        recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
        PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen",
        as: "https://www.w3.org/ns/activitystreams#"
      }.merge(dwc_contexts)
       .merge({ datasetKey: "http://rs.gbif.org/terms/1.0/datasetKey" })

      output = StringIO.open("", "w+")
      w = Oj::StreamWriter.new(output, indent: 1)
      w.push_object()
      w.push_value(context.as_json, "@context")
      w.push_key("@type")
      w.push_value("Person")
      w.push_key("@id")
      w.push_value("https://bloodhound-tracker.net/#{@user.identifier}")
      w.push_key("givenName")
      w.push_value(@user.given)
      w.push_key("familyName")
      w.push_value(@user.family)
      w.push_value(@user.other_names.split("|"), "alternateName")
      w.push_key("sameAs")
      w.push_value(@user.uri)

      identifications = jsonld_occurrences("identifications")
      recordings = jsonld_occurrences("recordings")

      first_url = "#{base_url}#{identifications[:metadata][:first_url] || recordings[:metadata][:first_url]}"
      w.push_value(first_url, "as:first")

      if identifications[:metadata][:prev].nil? && recordings[:metadata][:prev].nil?
        prev_url = nil
      else
        prev_url = "#{base_url}#{identifications[:metadata][:prev_url] || recordings[:metadata][:prev_url]}"
      end
      w.push_value(prev_url, "as:prev")

      #TODO: fix current URL, first, prev URL when page number exceeds what's available
      current_url = "#{base_url}#{identifications[:metadata][:page_url] || recordings[:metadata][:page_url]}"
      w.push_value(current_url, "as:current")

      if identifications[:metadata][:next].nil? && recordings[:metadata][:next].nil?
        next_url = nil
      else
        next_url = "#{base_url}#{identifications[:metadata][:next_url] || recordings[:metadata][:next_url]}"
      end
      w.push_value(next_url, "as:next")

      w.push_object("@reverse")
      w.push_array("identified")
      identifications[:results].each do |o|
        w.push_value(o.as_json)
      end
      w.pop
      w.push_array("recorded")
      recordings[:results].each do |o|
        w.push_value(o.as_json)
      end
      w.pop
      w.pop_all
      output.string()
    end

    def jsonld_occurrences(type="identifcations")
      begin
        pagy, results = pagy_countless(@user.send(type), items: 100)
        metadata = pagy_metadata(pagy)
      rescue
        results = []
        metadata = {
          first_url: nil,
          prev_url: nil,
          page_url: nil,
          next_url: nil,
          prev: nil,
          next: nil
        }
      end

      ignore_cols = Occurrence::IGNORED_COLUMNS_OUTPUT
      items = results.map do |o|
        { "@type": "PreservedSpecimen",
          "@id": "https://gbif.org/occurrence/#{o.occurrence.id}",
          sameAs: "https://gbif.org/occurrence/#{o.occurrence.id}"
        }.merge(o.occurrence.attributes.reject {|column| ignore_cols.include?(column)})
      end
      { metadata: metadata, results: items }
    end

  end

end
