#!/usr/bin/env ruby
# encoding: utf-8

require File.dirname(__FILE__) + '/environment.rb'

class BLOODHOUND < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :haml, :format => :html5
  set :public_folder, 'public'

  register Sinatra::I18nSupport
  load_locales File.join(root, 'config', 'locales')
  I18n.available_locales = [:en, :fr]

  register Config

  register Sinatra::Cacher
  register Sinatra::Flash
  register Sinatra::OutputBuffer
  set :cache_enabled_in, [:development, :production]

  use Rack::Locale
  use Rack::MethodOverride

  use Rack::Session::Cookie, key: 'rack.session',
                             path: '/',
                             secret: Settings.orcid_key

  use OmniAuth::Builder do
    provider :orcid, Settings.orcid_key, Settings.orcid_secret,
      :authorize_params => {
        :scope => '/authenticate'
      },
      :client_options => {
        :site => Settings.orcid_site,
        :authorize_url => Settings.orcid_authorize_url,
        :token_url => Settings.orcid_token_url,
        :token_method => :post,
        :scope => '/authenticate'
      }

    provider :zenodo, Settings.zenodo_key, Settings.zenodo_secret,
      :sandbox => Settings.zenodo_sandbox,
      :authorize_params => {
        :client_id => Settings.zenodo_key,
        :redirect_uri => Settings.base_url + '/auth/zenodo/callback'
      },
      :client_options => {
        :site => Settings.zenodo_site,
        :authorize_url => Settings.zenodo_authorize_url,
        :token_url => Settings.zenodo_token_url,
        :token_method => :post,
        :scope => 'deposit:write deposit:actions',
        :redirect_uri => Settings.base_url + '/auth/zenodo/callback'
      }
   end

  include Pagy::Backend
  include Pagy::Frontend
  Pagy::VARS[:items] = 30

  use Rack::GoogleAnalytics, tracker: Settings.google_analytics

  helpers Sinatra::ContentFor
  helpers Sinatra::Bloodhound::Formatters
  helpers Sinatra::Bloodhound::Helpers
  helpers Sinatra::Bloodhound::Queries
  helpers Sinatra::Bloodhound::Security
  helpers Sinatra::Bloodhound::Uploaders

  register Sinatra::Bloodhound::Controller::ApplicationController
  register Sinatra::Bloodhound::Controller::AdminController
  register Sinatra::Bloodhound::Controller::HelpingController
  register Sinatra::Bloodhound::Controller::OccurrenceController
  register Sinatra::Bloodhound::Controller::ProfileController
  register Sinatra::Bloodhound::Controller::UserController
  register Sinatra::Bloodhound::Controller::UserOccurrenceController

  register Sinatra::Bloodhound::Model::Initialize
  use Sinatra::Bloodhound::Model::QueryCache

  run! if app_file == $0
end
