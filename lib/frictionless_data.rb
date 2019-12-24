# encoding: utf-8

module Bloodhound
  class FrictionlessData

    def initialize(uuid:, output_directory:)
      @dataset = Dataset.find_by_datasetKey(uuid)
      @package = descriptor
      @output_dir = output_directory
      Zip.on_exists_proc = true
      Zip.continue_on_exists_proc = true
    end

    def create_package
      add_resources
      dir = File.join(@output_dir, @dataset.datasetKey)
      FileUtils.mkdir(dir) unless File.exists?(dir)

      #Add datapackage.json
      File.open(File.join(dir, "datapackage.json"), 'wb') { |file| file.write(JSON.pretty_generate(@package)) }

      #Add data files
      #TODO: optimize by combining user_occurrences and claimed_occurrences as a single method in dataset model
      #TODO: users method in dataset model performs poorly with large datasets
      tables = ["users", "occurrences", "attributions"]
      tables.each do |table|
        file = File.open(File.join(dir, "#{table}.csv"), "wb")
        send("#{table}_data_enum").each { |line| file << line }
        file.close
      end

      #Zip directory
      zip_file = File.join(@output_dir, "#{@dataset.datasetKey}.zip")
      Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
        ["datapackage.json"].concat(tables.map{|t| "#{t}.csv"}).each do |filename|
          zipfile.add(filename, File.join(dir, filename))
        end
      end
      FileUtils.remove_dir(dir)
    end

    def add_resources
      @package[:resources] << user_resource
      @package[:resources] << occurrence_resource
      @package[:resources] << attribution_resource
    end

    def descriptor
      license_name = ""
      if @dataset.license.include?("/zero/1.0/")
        license_name = "CC0 1.0 Universal (CC0 1.0) Public Domain Dedication"
      elsif @dataset.license.include?("/by/4.0/")
        license_name = "Attribution 4.0 International (CC BY 4.0)"
      elsif @dataset.license.include?("/by-nc/4.0/")
        license_name = "Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)"
      end

      {
        name: "#{@dataset.title}",
        id: "https://doi,org/#{@dataset.doi}",
        licenses: [
          {
            name: license_name,
            path: @dataset.license
          }
        ],
        profile: "tabular-data-package",
        title: "#{@dataset.title}",
        description: "#{@dataset.description}",
        datasetKey: @dataset.datasetKey,
        resources: []
      }
    end

    def user_resource
      {
        name: "users",
        path: "users.csv",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "id", type: "integer" },
            { name: "name", type: "string", rdfType: "http://schema.org/name" },
            { name: "familyName", type: "string", rdfType: "http://schema.org/familyName" },
            { name: "givenName", type: "string", rdfType: "http://schema.org/givenName" },
            { name: "alternateName", type: "array", rdfType: "http://schema.org/alternateName" },
            { name: "sameAs", type: "string", format: "uri", rdfType: "http://schema.org/sameAs" },
            { name: "orcid", type: "string" },
            { name: "wikidata", type: "string" },
            { name: "birthDate", type: "date", rdfType: "https://schema.org/birthDate" },
            { name: "deathDate", type: "date", rdfType: "https://schema.org/deathDate" }
          ]
        },
        primaryKey: "id"
      }
    end

    def occurrence_resource
      fields = [
        { name: "gbifID", type: "integer"},
        { name: "datasetKey", type: "string", format: "uuid" }
      ]
      fields.concat(Occurrence.accepted_fields.map{|o| {
              name: "#{o}",
              type: "string",
              rdfType: ("http://rs.tdwg.org/dwc/terms/#{o}" if o != "countryCode")
            }.compact
          })
      {
        name: "occurrences",
        path: "occurrences.csv",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: fields
        },
        primaryKey: "gbifID"
      }
    end

    def attribution_resource
      {
        name: "attributions",
        path: "attributions.csv",
        format: "csv",
        mediatype: "text/csv",
        encoding: "utf-8",
        profile: "tabular-data-resource",
        schema: {
          fields: [
            { name: "user_id", type: "integer" },
            { name: "occurrence_id", type: "integer "},
            { name: "identifiedBy", type: "string", format: "uri", rdfType: "http://rs.tdwg.org/dwc/iri/identifiedBy" },
            { name: "recordedBy", type: "string", format: "uri", rdfType: "http://rs.tdwg.org/dwc/iri/recordedBy" },
            { name: "claimedBy", type: "string" },
            { name: "claimedByURI", type: "string", format: "uri" },
            { name: "claimedDateTime", type: "datetime" }
          ]
        },
        foreignKeys: [
          {
            fields: "user_id",
            reference: {
              resource: "users",
              fields: "id"
            }
          },
          {
            fields: "occurrence_id",
            reference: {
              resource: "occurrences",
              fields: "id"
            }
          }
        ]
      }
    end

    def users_data_enum
      user_ids = Set.new
      Enumerator.new do |y|
        header = user_resource[:schema][:fields].map{ |u| u[:name] }
        y << CSV::Row.new(header, header, true).to_s
        @dataset.user_ids.find_each(batch_size: 25_000) do |u|
          user_ids.add u.user_id
        end
        user_ids.to_a.in_groups_of(25, false) do |group|
          User.where(id: group).find_each do |u|
            aliases = u.other_names.split("|").to_s if !u.other_names.blank?
            data = [
              u.id,
              u.fullname,
              u.family,
              u.given,
              aliases,
              u.uri,
              u.orcid,
              u.wikidata,
              u.date_born,
              u.date_died
            ]
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def occurrences_data_enum
      Enumerator.new do |y|
        header = occurrence_resource[:schema][:fields].map{ |u| u[:name] }
        y << CSV::Row.new(header, header, true).to_s
        @dataset.claimed_occurrences.find_each(batch_size: 10_000) do |o|
          data = o.attributes
                  .except("dateIdentified_processed", "eventDate_processed")
                  .values
          y << CSV::Row.new(header, data).to_s
        end
      end
    end

    def attributions_data_enum
      attributes = [
        "user_occurrences.id",
        "user_occurrences.user_id",
        "user_occurrences.occurrence_id",
        "user_occurrences.action",
        "user_occurrences.created AS claimDateTime",
        "users.wikidata",
        "users.orcid",
        "claimants_user_occurrences.given AS claimantGiven",
        "claimants_user_occurrences.family AS claimantFamily",
        "claimants_user_occurrences.orcid AS claimantORCID"
      ]
      Enumerator.new do |y|
        header = attribution_resource[:schema][:fields].map{ |u| u[:name] }
        y << CSV::Row.new(header, header, true).to_s
        @dataset.user_occurrences
                .select(attributes).find_each(batch_size: 10_000) do |o|
          uri = !o.orcid.nil? ? "https://orcid.org/#{o.orcid}" : "https://www.wikidata.org/wiki/#{o.wikidata}"
          identified_uri = o.action.include?("identified") ? uri : nil
          recorded_uri = o.action.include?("recorded") ? uri : nil
          claimant_name = [o.claimantGiven, o.claimantFamily].join(" ")
          claimant_orcid = !o.claimantORCID.blank? ? "https://orcid.org/#{o.claimantORCID}" : nil
          data = [
            o.user_id,
            o.occurrence_id,
            identified_uri,
            recorded_uri,
            claimant_name,
            claimant_orcid,
            o.claimDateTime
          ]
          y << CSV::Row.new(header, data).to_s
        end
      end
    end

  end
end
