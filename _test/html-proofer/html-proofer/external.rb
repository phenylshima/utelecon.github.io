# frozen_string_literal: true

require 'html_proofer'
require 'uri'

module CustomHTMLProofer
  class UrlValidator
    class External < HTMLProofer::UrlValidator::External
      def run_external_link_checker(external_urls)
        # Route log from Typhoeus/Ethon to our own logger
        Ethon.logger = @logger

        external_urls.each_pair do |external_url, metadata|
          url = HTMLProofer::Attribute::Url.new(@runner, external_url, base_url: nil)

          unless url.valid?
            add_failure(metadata, "#{url} is an invalid URL", 0)
            next
          end

          next unless new_url_query_values?(url)

          method = if @runner.options[:check_external_hash] && url.hash?
                     :get
                   else
                     :head
                   end

          req = create_request(method, url, metadata)
          req.run
          sleep(1)
        end
      end

      def create_request(method, url, filenames)
        opts = @runner.options[:typhoeus].merge(method: method)
        request = Typhoeus::Request.new(url.url, opts)
        @before_request.each do |callback|
          callback.call(request)
        end
        request.on_complete do |response|
          print url.url, ': ', response.code, "\n"
          response_handler(response, url, filenames)
        end
        request
      end
    end
  end
end
