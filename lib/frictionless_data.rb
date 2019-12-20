# encoding: utf-8

module Bloodhound
  class FrictionlessData

    def initialize(uuid:)
      @dataset = Dataset.find_by_datasetKey(uuid)
      dataset_descriptor[:resources] << occurrences_resource
      dataset_descriptor[:resources] << attributions_resource
      @package = DataPackage::Package.new(dataset_descriptor)
    end

    def dataset_descriptor
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

    def users_resource
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

    def occurrences_resource
      fields = [
        { name: "gbifID", type: "integer"},
        { name: "datasetKey", type: "string", format: "uuid" }
      ]
      fields << Occurrence.accepted_fields.map{|o| { 
              name: "#{o}",
              type: "string",
              rdfType: ("http://rs.tdwg.org/dwc/terms/#{o}" if o != "countryCode")
            }.compact 
          }
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

    def attributions_resource
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
            { name: "recordedBy", type: "string", format: "uri", rdfType: "http://rs.tdwg.org/dwc/iri/recordedBy" }
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

    #TODO: when making data resources, must constrain users and occurrences to only those that have attributions

    def add_users_data
    end

    def add_occurrences_data
    end

    def add_attributions_data
    end


  end
end