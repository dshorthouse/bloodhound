# encoding: utf-8

module Bloodhound
  class GbifTracker

    def initialize(args = {})
      @url = "https://www.gbif.org/api/resource/search?contentType=literature&limit=200&offset="
      args = defaults.merge(args)
      @first_page_only = args[:first_page_only]
      @max_size = args[:max_size]
      Zip.on_exists_proc = true
    end

    def create_package_records
      citation_downloads_enum.each do |item|
        begin
          Article.create item
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end
    end

    def datapackage_file_size(key)
      begin
        response = RestClient::Request.execute(
          method: :get,
          url: "https://www.gbif.org/api/occurrence/download/#{key}"
        )
        result = JSON.parse(response, :symbolize_names => true)
        result[:size]
      rescue
        @max_size
      end
    end

    def process_data_packages
      url = "http://api.gbif.org/v1/occurrence/download/request/"
      Article.where(processed: false).find_each do |article|
        article.gbif_downloadkeys.each do |key|
          if datapackage_file_size(key) < @max_size
            tmp_file = Tempfile.new('gbif')
            zip = RestClient.get("#{url}#{key}.zip") rescue nil
            next if zip.nil?
            File.open(tmp_file, 'wb') do |output|
              output.write zip
            end
            begin
              dwc = DarwinCore.new(tmp_file)
              gbifID = dwc.core.fields.select{|term| term[:term] == "http://rs.gbif.org/terms/1.0/gbifID"}[0][:index]
              dwc.core.read(1000) do |data, errors|
                ArticleOccurrence.import data.map{|a| { article_id: article.id, occurrence_id: a[gbifID].to_i } }, validate: false
              end
            rescue
              tmp_csv = Tempfile.new('gbif_csv')
              Zip::File.open(tmp_file) do |zip_file|
                entry = zip_file.glob('*.csv').first
                if entry
                  entry.extract(tmp_csv)
                  items = []
                  CSV.foreach(tmp_csv, headers: :first_row, col_sep: "\t", liberal_parsing: true, quote_char: "\x00") do |row|
                    occurrence_id = row["gbifid"] || row["gbifID"]
                    next if occurrence_id.nil?
                    items << ArticleOccurrence.new(article_id: article.id, occurrence_id: occurrence_id)
                  end
                  ArticleOccurrence.import items, batch_size: 1_000, validate: false
                end
              end
              tmp_csv.unlink
            end
            tmp_file.unlink
          end
        end
        article.processed = true
        article.save
      end
    end

    def citation_downloads_enum
      Enumerator.new do |yielder|
        offset = 0
        loop do
          response = RestClient::Request.execute(
            method: :get,
            url: "#{@url}#{offset}"
          )
          results = JSON.parse(response, :symbolize_names => true)[:results] rescue []
          if results.size > 0
            results.each do |result|
              begin
                if result[:identifiers][:doi] && !result[:gbifDownloadKey].empty?
                  yielder << { 
                    doi: result[:identifiers][:doi],
                    abstract: result[:abstract],
                    gbif_dois: result[:_gbifDOIs].map{ |d| d.sub("doi:","") },
                    gbif_downloadkeys: result[:gbifDownloadKey],
                    created: result[:created]
                  }
                end
              rescue
              end
            end
          else
            raise StopIteration
          end
          break if @first_page_only
          offset += 200
        end
      end.lazy
    end

    private

    def defaults
      { first_page_only: false, max_size: 100_000_000 }
    end

  end
end