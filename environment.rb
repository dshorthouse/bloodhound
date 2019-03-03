require 'bundler'
require 'ostruct'
require 'logger'
require 'mysql2'
require 'active_record'
require 'active_record_union'
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
require 'pagy'
require 'pagy/extras/array'
require 'pagy/extras/bootstrap'
require 'chronic'
require 'omniauth-orcid'
require 'thin'
require 'oauth2'
require 'require_all'
require 'nokogiri'
require 'uri'
require 'net/http'
require 'rack/google-analytics'
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
require 'colorize'
require 'sinatra/cacher'
require 'sinatra/outputbuffer'
require 'ruby-progressbar'
require 'dwc_archive'
require 'zip'
require 'biodiversity'
require 'rss'
require 'xml-sitemap'
require 'wikidata'

Hashie.logger = Logger.new(nil)

register Sinatra::ConfigFile
config_file File.join(File.dirname(__FILE__), 'config.yml')

require_all File.join(File.dirname(__FILE__), 'lib')
require_all File.join(File.dirname(__FILE__), 'helpers')
require_all File.join(File.dirname(__FILE__), 'controllers')
require_all File.join(File.dirname(__FILE__), 'models')

register Sinatra::Bloodhound::Model::Initialize