# encoding: utf-8

module Bloodhound
  class GbifDataset

    def initialize
      @url = "http://api.gbif.org/v1/dataset?limit=100&offset="
    end

    def create_records
      datasets_list_enum.each do |item|
        begin
          Dataset.create item
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end
    end

    def process_dataset(datasetkey)
      begin
        response = RestClient::Request.execute(
          method: :get,
          url: "http://api.gbif.org/v1/dataset/#{datasetkey}"
        )
        response = JSON.parse(response, :symbolize_names => true) rescue []
        dataset = Dataset.create_or_find_by({
          datasetKey: response[:key]
        })
        dataset.description = response[:description] || nil
        dataset.title = response[:title]
        dataset.doi = response[:doi] || nil
        dataset.license = response[:license] || nil
        dataset.image_url = response[:logoUrl] || nil
        dataset.save
      rescue
      end
    end

    def datasets_list_enum
      Enumerator.new do |yielder|
        offset = 0
        loop do
          sleep 2
          response = RestClient::Request.execute(
            method: :get,
            url: "#{@url}#{offset}"
          )
          response = JSON.parse(response, :symbolize_names => true) rescue []
          if response[:results].size > 0
            if response[:count].to_i > offset
              response[:results].each do |result|
                begin
                  if result[:key] && result[:type] == "OCCURRENCE"
                    yielder << {
                      datasetKey: result[:key],
                      doi: result[:doi],
                      title: result[:title],
                      description: result[:description],
                      license: result[:license],
                      image_url: result[:logoUrl]
                    }
                  end
                rescue
                end
              end
            end
          else
            raise StopIteration
          end
          offset += 100
        end
      end.lazy
    end

  end
end
