# make sure to include the needed pagination modules
require 'will_paginate'
require 'will_paginate/view_helpers/sinatra'

module WillPaginate
  module Sinatra
    module Helpers
      include ViewHelpers

      def will_paginate(collection, options = {})
        options[:renderer] ||= BootstrapLinkRenderer
        super(collection, options)
      end
    end

    class BootstrapLinkRenderer < LinkRenderer
      protected
      
      def html_container(html)
        tag :nav, tag(:ul, html, class: @options[:class]), container_attributes
      end

      def page_number(page)
        status = 'active' if page == current_page
        tag :li, link(page, page, :rel => rel_value(page), class: "page-link"), :class => "page-item #{status}"
      end

      def previous_or_next_page(page, text, classname)
        tag :li, link(text, page || '#', class: "page-link"), :class => [classname[0..3], classname, ('disabled' unless page)].join(' ')
      end
    end
  end
end