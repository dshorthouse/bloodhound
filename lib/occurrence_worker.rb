# encoding: utf-8

module Bloodhound
  class OccurrenceWorker
    include Sidekiq::Worker
    sidekiq_options queue: :occurrence

    def perform(o)
      keys = o["indices"].keys
      tmp_file = o["tmp_file"]
      csv_options = o["csv_options"]
      sql = "LOAD DATA INFILE '#{tmp_file}' 
             INTO TABLE occurrences 
             CHARACTER SET UTF8 
             FIELDS TERMINATED BY ',' 
             OPTIONALLY ENCLOSED BY '\"'
             LINES TERMINATED BY '\n'
             (" + keys.join(",") + ")"
      begin
        Occurrence.connection.execute sql
      rescue ActiveRecord::StatementInvalid
        CSV.foreach(tmp_file) do |row|
          Occurrence.create(keys.zip(row).to_h)
        end
      end
      FileUtils.rm(tmp_file)
    end

  end
end