# encoding: utf-8

module Sinatra
  module Bloodhound
    module Formatters

      def h(text)
        Rack::Utils.escape_html(text)
      end

      def checked_tag(user_action, action)
        (user_action == action) ? "checked" : ""
      end

      def active_class(user_action, action)
        (user_action == action) ? "active" : ""
      end

      def number_with_delimiter(number, default_options = {})
        options = {
          :delimiter => ','
        }.merge(default_options)
        number.to_s.reverse.gsub(/(\d{3}(?=(\d)))/, "\\1#{options[:delimiter]}").reverse
      end

      def profile_image(user, size=nil)
        img = "/images/photo.png"
        cloud_img = "https://abekpgaoen.cloudimg.io/height/200/x/"
        if size == "thumbnail"
          cloud_img = "https://abekpgaoen.cloudimg.io/crop/24x24/n/"
        elsif size == "thumbnail_grey"
          cloud_img = "https://abekpgaoen.cloudimg.io/crop/24x24/fgrey/"
        elsif size == "medium"
          cloud_img = "https://abekpgaoen.cloudimg.io/crop/48x48/n/"
        elsif size == "social"
          cloud_img = "https://abekpgaoen.cloudimg.io/crop/240x240/n/"
        end
        if user.image_url
          if user.wikidata
            img =  cloud_img + user.image_url
          else
            img = cloud_img + Settings.base_url + "/images/users/" + user.image_url
          end
        end
        img
      end

      def organization_image(organization, size=nil)
        img = nil
        cloud_img = "https://abekpgaoen.cloudimg.io/height/200/x/"
        if size == "thumbnail"
          cloud_img = "https://abekpgaoen.cloudimg.io/crop/24x24/n/"
        elsif size == "medium"
          cloud_img = "https://abekpgaoen.cloudimg.io/crop/48x48/n/"
        end
        if organization.image_url
          img = cloud_img + organization.image_url
        end
        img
      end

      def signature_image(user)
        img = "/images/signature.png"
        cloud_img = "https://abekpgaoen.cloudimg.io/height/80/x/"
        if user.signature_url
          img =  cloud_img + user.signature_url
        end
        img
      end

      def format_agent(n)
        { id: n[:_source][:id],
          score: n[:_score],
          name: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", ")
        }
      end

      def format_agents
        @results.map{ |n|
          { id: n[:_source][:id],
            score: n[:_score],
            fullname: n[:_source][:fullname],
            fullname_reverse: [n[:_source][:family].presence, n[:_source][:given].presence].compact.join(", ")
          }
        }
      end

      def format_users
        @results.map{ |n|
          { id: n[:_source][:id],
            score: n[:_score],
            orcid: n[:_source][:orcid],
            wikidata: n[:_source][:wikidata],
            fullname: n[:_source][:fullname],
            fullname_reverse: n[:_source][:fullname_reverse]
          }
        }
      end

      def format_organizations
        @results.map{ |n|
          { id: n[:_source][:id],
            score: n[:_score],
            name: n[:_source][:name],
            address: n[:_source][:address],
            institution_codes: n[:_source][:institution_codes],
            isni: n[:_source][:isni],
            ringgold: n[:_source][:ringgold],
            grid: n[:_source][:grid],
            wikidata: n[:_source][:wikidata],
            preferred: n[:_source][:preferred]
          }
        }
      end

      def format_datasets
        @results.map{ |n|
          { id: n[:_source][:id],
            score: n[:_score],
            title: n[:_source][:title],
            datasetkey: n[:_source][:datasetkey]
          }
        }
      end

      def format_lifespan(user)
        born = !user.date_born.nil? ? user.date_born.to_formatted_s(:long) : "?"
        died = !user.date_died.nil? ? user.date_died.to_formatted_s(:long) : "?"
        "(" + ["b. " + born, "d. " + died].join(" &ndash; ") + ")"
      end

    end
  end
end