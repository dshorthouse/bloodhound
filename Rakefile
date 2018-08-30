require 'rake'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'byebug'
require './environment'

task :default => :test
task :test => :spec

if !defined?(RSpec)
  puts "spec targets require RSpec"
else
  desc "Run all examples"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*.rb'
  end
end

# usage: rake generate:migration[name_of_migration]
namespace :generate do
  task(:migration, :migration_name) do |t, args|
    timestamp = Time.now.gmtime.to_s[0..18].gsub(/[^\d]/, '')
    migration_name = args[:migration_name]
    file_name = "%s_%s.rb" % [timestamp, migration_name]
    class_name = migration_name.split("_").map {|w| w.capitalize}.join('')
    path = File.join(File.expand_path(File.dirname(__FILE__)), 'db', 'migrate', file_name)
    f = open(path, 'w')
    content = "class #{class_name} < ActiveRecord::Migration
  def up
  end
  
  def down
  end
end
"
    f.write(content)
    puts "Generated migration %s" % path
    f.close
 end
end

namespace :db do
  require 'active_record'
  conf = YAML.load(open(File.join(File.expand_path(File.dirname(__FILE__)), 'config.yml')).read).deep_symbolize_keys
  env = Sinatra::Application.settings.environment
  desc "Migrate the database"
  task(:migrate => :environment) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate("db/migrate")
  end

  namespace :drop do
    task(:all) do
      if ['0.0.0.0', '127.0.0.1', 'localhost'].include?(conf[env][:host].strip)
        database = conf[env].delete(:database)
        ActiveRecord::Base.establish_connection(conf[env])
        ActiveRecord::Base.connection.execute("drop database if exists  #{database}")
      end
    end
  end
  
  namespace :create do
    task(:all) do
      if ['0.0.0.0', '127.0.0.1', 'localhost'].include?(conf[env][:host].strip)
        database = conf[env].delete(:database)
        ActiveRecord::Base.establish_connection(conf[env])
        ActiveRecord::Base.connection.execute("create database if not exists #{database}")
      end
    end
  end

end

task :environment do
  require_relative './environment'
end
