require './application.rb'
require 'sinatra'

set :run, true
set :environment, :production

run Rack::URLMap.new('/' => BLOODHOUND, '/sidekiq' => Sidekiq::Web)
