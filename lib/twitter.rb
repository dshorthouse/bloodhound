# encoding: utf-8

module Bloodhound
  class Twitter

    attr_reader :client
    attr_reader :base_url

    def initialize(ops = {})
      settings = Settings.merge!(opts)
      @client = ::Twitter::REST::Client.new do |config|
        config.consumer_key        = settings.twitter_consumer_key
        config.consumer_secret     = settings.twitter_consumer_secret
        config.access_token        = settings.twitter_access_token
        config.access_token_secret = settings.twitter_access_token_secret
      end
      @base_url = settings.base_url
    end

    def welcome_user(user)
      return if user.nil? || user.class.name != "User"
      id_statement = nil
      recorded_statement = nil
      twitter = nil
      statement = nil
      if !user.twitter.nil?
        twitter = "@#{user.twitter}"
      end
      if !user.top_family_identified.nil?
        id_statement = "identified #{user.top_family_identified}"
      end
      if !user.top_family_recorded.nil?
        recorded_statement = "collected #{user.top_family_recorded}"
      end
      if !user.top_family_identified.nil? || !user.top_family_recorded.nil?
        statement = [id_statement,recorded_statement].compact.join(" and ")
      end
      url = "#{@base_url}/#{user.identifier}"
      message = "#{user.fullname} #{twitter} #{statement} #{url}".split.join(" ")
      @client.update(message)
    end

  end
end