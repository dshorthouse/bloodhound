#!/usr/bin/env ruby
require './environment'

class BLOODHOUND < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :haml, :format => :html5
  set :public_folder, 'public'

  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8

  register Sinatra::ConfigFile
  config_file File.join(root, 'config.yml')

  register Sinatra::Cacher
  register Sinatra::OutputBuffer
  set :cache_enabled_in, [:development, :production]

  use Rack::MethodOverride

  use Rack::Session::Cookie, :key => 'rack.session',
                             :path => '/',
                             :secret => settings.orcid_key

  include Pagy::Backend
  include Pagy::Frontend
  Pagy::VARS[:items] = 30

  use OmniAuth::Builder do
    provider :orcid, settings.orcid_key, settings.orcid_secret,
      :authorize_params => {
        :scope => '/authenticate'
      },
      :client_options => {
        :site => settings.orcid_site,
        :authorize_url => settings.orcid_authorize_url,
        :token_url => settings.orcid_token_url,
        :token_method => :post,
        :scope => '/authenticate'
      }

      provider :zenodo, settings.zenodo_key, settings.zenodo_secret,
        :sandbox => settings.zenodo_sandbox,
        :authorize_params => {
          :client_id => settings.zenodo_key,
          :redirect_uri => settings.base_url + '/auth/zenodo/callback'
        },
        :client_options => {
          :site => settings.zenodo_site,
          :authorize_url => settings.zenodo_authorize_url,
          :token_url => settings.zenodo_token_url,
          :token_method => :post,
          :scope => 'deposit:write deposit:actions',
          :redirect_uri => settings.base_url + '/auth/zenodo/callback'
        }
  end

  use Rack::GoogleAnalytics, :tracker => settings.google_analytics

  helpers Sinatra::ContentFor
  helpers Sinatra::Bloodhound::Formatters
  helpers Sinatra::Bloodhound::Helpers
  helpers Sinatra::Bloodhound::Queries
  helpers Sinatra::Bloodhound::Security
  helpers Sinatra::Bloodhound::Uploaders

  register Sinatra::Bloodhound::Controller::ApplicationController
  register Sinatra::Bloodhound::Controller::AdminController
  register Sinatra::Bloodhound::Controller::HelpingController
  register Sinatra::Bloodhound::Controller::ProfileController
  register Sinatra::Bloodhound::Controller::UserController
  register Sinatra::Bloodhound::Controller::UserOccurrenceController

  register Sinatra::Bloodhound::Model::Initialize
  use Sinatra::Bloodhound::Model::QueryCache

  run! if app_file == $0
end