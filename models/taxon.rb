class Taxon < ActiveRecord::Base
  has_many :taxon_determiners
  has_many :determinations, through: :taxon_determiners, source: :agent

  has_many :taxon_occurrences
  has_many :occurrences, through: :taxon_occurrences, source: :occurrence

  def self.populate_metadata
    Parallel.map(Taxon.find_each, progress: "Metadata") do |t|
      next if t.common || t.image
      response = RestClient::Request.execute(
        method: :get,
        url: Sinatra::Application.settings.eol_api + 'search/1.0.json?exact=true&q=' + URI::encode(t.family),
      )
      parse_search_eol_response(t, response)
    end
  end

  def self.populate_kingdoms
    accepted = ["Animalia", "Plantae", "Fungi", "Protista", "Chromista", "Protozoa"]
    taxa = Taxon.where(kingdom: nil)
    pbar = ProgressBar.create(title: "Kingdoms", total: taxa.count, autofinish: false, format: '%t %b>> %i| %e')
    taxa.find_each do |t|
      response = RestClient::Request.execute(
        method: :get,
        url: Sinatra::Application.settings.gn_api + 'name_resolvers.json?data_source_ids=11&names=' + URI::encode(t.family),
      )
      results = JSON.parse(response, :symbolize_names => true)
      kingdom = results[:data][0][:results][0][:classification_path].split("|")[0] rescue nil
      if accepted.include?(kingdom)
        t.kingdom = kingdom
        t.save
      end
      pbar.increment
    end
    pbar.finish
  end

  def self.parse_search_eol_response(taxon, response)
    results = JSON.parse(response, :symbolize_names => true)
    id = results[:results][0][:id] rescue nil
    if !id.nil?
      response = RestClient::Request.execute(
        method: :get,
        url: Sinatra::Application.settings.eol_api + 'pages/1.0/' + id.to_s + '.json?common_names=true&images=1&details=true&videos=0&sounds=0&maps=0&text=0'
      ) rescue nil
      parse_page_eol_response(taxon, response) if !response.nil?
    end
  end

  def self.parse_page_eol_response(taxon, response)
    results = JSON.parse(response, :symbolize_names => true)
    common = nil
    image = nil
    results[:vernacularNames].each do |vn|
      if vn[:language] == "en" && vn[:eol_preferred]
        common = vn[:vernacularName]
        break
      end
    end
    if results[:dataObjects].length > 0 && results[:dataObjects][0][:dataType] == "http://purl.org/dc/dcmitype/StillImage"
      image = results[:dataObjects][0].to_json
    end
    taxon.common = common
    taxon.image = image
    taxon.save
  end

  def image_data
    content = JSON.parse(image, :symbolize_names => true) rescue nil
    return if content.nil?
    { mediaURL: content[:eolMediaURL], license: content[:license], rightsHolder: content[:rightsHolder], source: content[:source] }
  end

  def occurrence_coordinates
    occurrences.map(&:coordinates).uniq.compact
  end

end