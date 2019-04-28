# encoding: utf-8
require 'filemagic'

module Bloodhound
  class Zenodo

    def initialize(hash:)
      @hash = hash
    end

    def settings
      Sinatra::Application.settings
    end

    def client
      @client ||= OAuth2::Client.new(settings.zenodo_key, settings.zenodo_secret,
                      site: settings.zenodo_site,
                      authorize_url: settings.zenodo_authorize_url,
                      token_url:  settings.zenodo_token_url,
                      token_method: :post) do |stack|
                        stack.request :multipart
                        stack.request :url_encoded
                        stack.adapter  Faraday.default_adapter
                  end
    end

    def new_deposit_url
      "/api/deposit/depositions"
    end

    def deposit_url(id)
      "/api/deposit/depositions/#{id}"
    end

    def deposits_url
      "/api/deposit/depositions"
    end

    def add_file_url(id)
      "/api/deposit/depositions/#{id}/files"
    end

    def delete_file_url(id, file_id)
      "/api/deposit/depositions/#{id}/files/#{file_id}"
    end

    def new_version_url(id)
      "/api/deposit/depositions/#{id}/actions/newversion"
    end

    def publish_url(id)
      "/api/deposit/depositions/#{id}/actions/publish"
    end

    def access_token
      @access_token ||= OAuth2::AccessToken.from_hash(client, @hash)
    end

    # Have to store this again otherwise can no longer use the old one
    def refresh_token
      @access_token = access_token.refresh!
      @access_token.to_hash.deep_symbolize_keys
    end

    def list_deposits
      response = access_token.get(deposits_url)
      JSON.parse(response.body).map(&:deep_symbolize_keys)
    end

    def get_deposit(id:)
      response = access_token.get(deposit_url(id))
      JSON.parse(response.body).deep_symbolize_keys
    end

    # Input, name: "Shorthouse, David", orcid: "0000-0001-7618-5230"
    # Returns {:doi=>"10.5281/zenodo.2652234", :recid=>2652234}
    def new_deposit(name:, orcid:)
      headers = { "Content-Type": "application/json"}
      creators = [{ name: name, orcid: orcid }]
      body = {
        metadata: { upload_type: "dataset", 
          title: "Natural history specimens collected and/or identified and deposited.", 
          creators: creators,
          description: "Natural history specimen data collected and/or identified by #{name}, <a href=\"https://orcid.org/#{orcid}\">https://orcid.org/#{orcid}</a>. Claims were made on Bloodhound, <a href=\"http://bloodhound-tracker.net\">https://bloodhound-tracker.net</a> using specimen data from the Global Biodiversity Information Facility, <a href=\"https://gbif.org\">https://gbif.org</a>.",
          access_right: "open",
          license: "cc-zero"
        }
      }
      raw_response = access_token.post(new_deposit_url, { body: body.to_json, headers: headers })
      response = JSON.parse(raw_response.body).deep_symbolize_keys
      response[:metadata][:prereserve_doi]
    end

    def add_file(id:, file_path:, file_name: nil)
      filename = file_name ||= File.basename(file_path)
      io = File.new(file_path, "r")
      mime_type = FileMagic.new(FileMagic::MAGIC_MIME).file(file_path)
      upload = Faraday::UploadIO.new io, mime_type, filename
      response = access_token.post(add_file_url(id), { body: { filename: filename, file: upload }})
      JSON.parse(response.body).deep_symbolize_keys
    end

    def add_file_enum(id:, enum:, file_name:)
      temp = Tempfile.new
      enum.each { |line| temp << line }
      temp.close
      add_file(id: id, file_path: temp.path, file_name: file_name)
      temp.unlink
    end

    def delete_file(id:, file_id:)
      access_token.delete(delete_file_url(id, file_id))
    end

    def new_version(id:)
      response = access_token.post(new_version_url(id))
      response = JSON.parse(response.body).deep_symbolize_keys
      new_id = response[:links][:latest_draft].split("/").last.to_i
      get_deposit(id: new_id)
    end

    # concept DOI is returned as [:conceptdoi] whereas version DOI is [:doi]
    def publish(id:)
      response = access_token.post(publish_url(id))
      JSON.parse(response.body).deep_symbolize_keys
    end

  end
end