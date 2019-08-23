#!/usr/bin/env ruby
require './environment'

class BLOODHOUND < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :haml, :format => :html5
  set :public_folder, 'public'

  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8

  register Sinatra::I18nSupport
  load_locales File.join(root, 'config', 'locales')
  I18n.available_locales = [:en, :fr]

  register Sinatra::ConfigFile
  config_file File.join(root, 'config.yml')

  register Sinatra::Cacher
  register Sinatra::OutputBuffer
  set :cache_enabled_in, [:development, :production]

  use Rack::Locale
  use Rack::MethodOverride

  use Rack::Session::Cookie, key: 'rack.session',
                             path: '/',
                             secret: orcid_key

  include Pagy::Backend
  include Pagy::Frontend
  Pagy::VARS[:items] = 30

  use Rack::GoogleAnalytics, tracker: google_analytics

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
