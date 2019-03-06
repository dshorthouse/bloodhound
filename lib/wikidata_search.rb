# encoding: utf-8

module Bloodhound
  class WikidataSearch

    def account_data(wikicode)
      wiki_user = Wikidata::Item.find(wikicode)
      parsed = Namae.parse(wiki_user.title)[0] rescue nil
      family = parsed.family rescue nil
      given = parsed.given rescue nil
      country = wiki_user.properties("P27").compact.map(&:title).join("|") rescue nil
      country_code = wiki_user.properties("P27").compact.map{|a| IsoCountryCodes.search_by_name(a.title).first.alpha2}.join("|") rescue nil
      other_names = wiki_user.aliases.values.compact.map{|a| a.map{|b| b.value if b.language == "en"}.compact}.flatten.uniq.join("|") rescue nil
      date_born = Date.parse(wiki_user.properties("P569").compact.map{|a| a.value.time if a.precision_key == :day}.compact.first) rescue nil
      date_died = Date.parse(wiki_user.properties("P570").compact.map{|a| a.value.time if a.precision_key == :day}.compact.first) rescue nil
      {
        family: family,
        given: given,
        other_names: other_names,
        country: country,
        country_code: country_code,
        date_born: date_born,
        date_died: date_died
      }
    end

  end
end