# encoding: utf-8
class String
  def is_orcid?
    ::Bloodhound::Identifier.is_orcid_regex.match?(self)
  end
  def is_wiki_id?
    ::Bloodhound::Identifier.is_wiki_regex.match?(self)
  end
  def is_doi?
    ::Bloodhound::Identifier.is_doi_regex.match?(self)
  end

  def orcid_from_url
    ::Bloodhound::Identifier.extract_orcid_regex.match(self)[0] rescue nil
  end
  def wiki_from_url
    ::Bloodhound::Identifier.extract_wiki_regex.match(self)[0] rescue nil
  end
  def ipni_from_url
    ::Bloodhound::Identifier.extract_ipni_regex.match(self)[0] rescue nil
  end
  def viaf_from_url
    ::Bloodhound::Identifier.extract_viaf_regex.match(self)[0] rescue nil
  end
  def bhl_from_url
    ::Bloodhound::Identifier.extract_bhl_regex.match(self)[0] rescue nil
  end
  def isni_from_url
    URI.decode_www_form_component(::Bloodhound::Identifier.extract_isni_regex.match(self)[0]) rescue nil
  end
end

module Bloodhound
  class Identifier

    class << self
      def is_orcid_regex
        /^(\d{4}-){3}\d{3}[0-9X]{1}$/
      end

      def is_wiki_regex
        /^Q[0-9]{1,}$/
      end

      def is_doi_regex
        /^10.\d{4,9}\/[-._;()\/:<>A-Z0-9]+$/i
      end

      def extract_orcid_regex
        /(?<=orcid\.org\/)(\d{4}-){3}\d{3}[0-9X]{1}/
      end

      def extract_wiki_regex
        /(?:wikidata\.org\/(entity|wiki)\/)\K(Q[0-9]{1,})/
      end

      def extract_ipni_regex
        /(?:ipni.org\/(?:.*)\?id\=)\K(.*)/
      end

      def extract_viaf_regex
        /(?<=viaf.org\/viaf\/)([0-9]{1,})/
      end

      def extract_bhl_regex
        /(?<=biodiversitylibrary.org\/creator\/)([0-9]{1,})/
      end

      def extract_isni_regex
        /(?<=isni.org\/)(.*)/
      end

    end

  end
end
