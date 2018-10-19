require 'bundler'
require 'ostruct'
require 'logger'
require 'mysql2'
require 'active_record'
require 'activerecord-import'
require 'active_support/all'
require 'rest_client'
require 'json'
require 'sanitize'
require 'htmlentities'
require 'tilt/haml'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/config_file'
require 'yaml'
require 'namae'
require 'elasticsearch'
require 'will_paginate'
require 'will_paginate/array'
require 'will_paginate/collection'
require 'will_paginate/active_record'
require 'will_paginate/view_helpers/sinatra'
require 'chronic'
require 'omniauth-orcid'
require 'thin'
require 'oauth2'
require 'require_all'
require 'nokogiri'
require 'uri'
require 'net/http'
require 'ruby-progressbar'
require 'rack/google-analytics'
require 'parallel'
require 'redis'
require 'net/http'
require 'uri'
require 'capitalize_names'
require 'csv'
require 'sidekiq'
require 'sidekiq/web'
require 'dwc_agent'
require 'iso_country_codes'
require 'neo4j'
require 'byebug'

require_all 'lib'
require_all 'helpers'
require_all 'controllers'
require_all 'models'

register Sinatra::ConfigFile
config_file File.join(File.dirname(__FILE__), 'config.yml')

register Sinatra::Bloodhound::Model::Initialize