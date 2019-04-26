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

    def new_deposition_url
      "/api/deposit/depositions"
    end

    def add_file_url(id)
      "/api/deposit/depositions/#{id}/files"
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
      response = access_token.get("/api/deposit/depositions")
      JSON.parse(response.body).map(&:deep_symbolize_keys)
    end

    def get_deposit(id:)
      response = access_token.get("/api/deposit/depositions/#{id}")
      JSON.parse(response.body).deep_symbolize_keys
    end

    # Returns eg {:doi=>"10.5281/zenodo.2652234", :recid=>2652234}
    def new_deposit(name:, orcid:)
      headers = { "Content-Type": "application/json"}
      creators = [{ name: name, orcid: orcid }]
      body = {
        metadata: { upload_type: "dataset", 
          title: "Natural history specimens collected and/or identified and deposited.", 
          creators: creators,
          description: "Natural history specimen data collected and/or identified by #{name}, https://orcid.org/#{orcid}",
          access_right: "open",
          license: "cc-zero"
        }
      }
      raw_response = access_token.post(new_deposition_url, { body: body.to_json, headers: headers })
      response = JSON.parse(raw_response.body).deep_symbolize_keys
      response[:metadata][:prereserve_doi]
    end

    def add_file(id:, file_path:)
      filename = File.basename(file_path)
      io = File.new(file_path, "r")
      mime_type = FileMagic.new(FileMagic::MAGIC_MIME).file(file_path)
      upload = Faraday::UploadIO.new io, mime_type, filename
      response = access_token.post(add_file_url(id), { body: { filename: filename, file: upload }})
      JSON.parse(response.body).deep_symbolize_keys
    end

    def delete_file(id:, file_id:)
      access_token.delete("/api/deposit/depositions/#{id}/files/#{file_id}")
    end

    def new_version(id:)
      response = access_token.post(new_version_url(id))
      JSON.parse(response.body).deep_symbolize_keys
    end

    def publish(id:)
      response = access_token.post(publish_url(id))
      JSON.parse(response.body).deep_symbolize_keys
    end

  end
end