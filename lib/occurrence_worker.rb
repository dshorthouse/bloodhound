# encoding: utf-8

module Bloodhound
  class OccurrenceWorker
    include Sidekiq::Worker
    sidekiq_options queue: :occurrence

    def perform(o)
      sql = "LOAD DATA INFILE '#{o["tmp_file"]}' 
             INTO TABLE occurrences 
             CHARACTER SET UTF8 
             FIELDS TERMINATED BY ',' 
             OPTIONALLY ENCLOSED BY '\"'
             LINES TERMINATED BY '\n'
             (" + o["indices"].keys.join(",") + ")"
      begin
        Occurrence.connection.execute sql
        FileUtils.rm(o["tmp_file"])
      rescue ActiveRecord::StatementInvalid
        puts o["tmp_file"] + " failed"
      end
    end

  end
end