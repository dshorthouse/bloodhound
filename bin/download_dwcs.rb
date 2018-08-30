#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'optparse'

ARGV << '-h' if ARGV.empty?

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage:download_dwcs.rb -uuid 8f83fc96-c966-4126-83f7-bf044dc49efa"

  opts.on("-u", "--uuid [UUID]", String, "UUID of GBIF node") do |uuid|
    options[:uuid] = uuid
  end

  opts.on("-d", "--directory [DIRECTORY]", String, "Destination directory for DwC files") do |directory|
    options[:directory] = directory
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

def http_download_uri(uri, filename)
  http_object = Net::HTTP.new(uri.host, uri.port)
  http_object.use_ssl = true if uri.scheme == 'https'
  begin
    http_object.start do |http|
      request = Net::HTTP::Get.new uri.request_uri
      http.read_timeout = 500
      http.request request do |response|
        open filename, 'w' do |io|
          response.read_body do |chunk|
            io.write chunk
          end
        end
      end
    end
  rescue Exception => e
    return
  end
end

def parse_response(response)
  results = JSON.parse(response, :symbolize_names => true)[:results]
  pbar = ProgressBar.create(title: "DwCs", total: results.size, autofinish: false, format: '%t %b>> %i| %e')
  results.each do |result|
    pbar.increment
    if result[:type] == "OCCURRENCE"
      title = result[:title]
      result[:endpoints].each do |endpoint|
        if endpoint[:type] == "DWC_ARCHIVE"
          uri = URI.parse(endpoint[:url])
          http_download_uri(uri, File.join(@directory, "#{result[:key]}.zip"))
        end
      end
    end
  end
  pbar.finish
end

if options[:uuid]
  uuid = options[:uuid]
  @directory = options[:directory] || "/tmp/dwc-#{Time.now.to_i}/"
  FileUtils.mkdir_p(@directory)
  response = RestClient::Request.execute(
    method: :get,
    url: "http://api.gbif.org/v1/node/#{uuid}/dataset?limit=1000",
  )
  parse_response(response)
end