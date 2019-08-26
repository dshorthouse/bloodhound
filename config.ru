require './application.rb'
require 'sinatra'

set :run, true
set :environment, :production

FileUtils.mkdir_p 'log' unless File.exists?('log')
log = File.new("log/sinatra.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)

run Rack::URLMap.new('/' => BLOODHOUND, '/sidekiq' => Sidekiq::Web)