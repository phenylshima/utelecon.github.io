# frozen_string_literal: true

require 'html_proofer'

require_relative 'external'
require_relative 'log'

module CustomHTMLProofer
  class Runner < HTMLProofer::Runner
    URL_TYPES = %i[external internal realpath].freeze

    def initialize(src, opts)
      super

      @logger = CustomHTMLProofer::Log.new(@options[:log_level])

      Runner.superclass.const_set(:URL_TYPES, URL_TYPES)
      @realpath_urls = {}
    end

    def report_failed_checks; end

    def check_parsed(path, source)
      should_check = true
      real = {}
      @html.xpath('/html/head/comment()').each do |node|
        text = node.text.strip
        next unless text.start_with?('html-proofer:')

        parse = /^html-proofer:\{check:(?<bool>true|false),path:"(?<path>.*)"\}$/.match(text)
        next if parse.nil? || !parse.names.include?('bool')

        should_check = false if parse[:bool] != 'true'
        real[path] = [parse[:path]] if parse.names.include?('path') && !path.empty?

        break
      end
      if should_check
        res = super
        res[:realpath_urls] = real
        res
      else
        { internal_urls: {}, external_urls: {},
          realpath_urls: real,
          failures: [
            HTMLProofer::Failure.new(path, 'Flag', '')
          ] }
      end
    end

    def realpath(path)
      @realpath_urls[path]
    end

    def validate_external_urls
      external_url_validator = CustomHTMLProofer::UrlValidator::External.new(self, @external_urls)
      @failures.concat(external_url_validator.validate)
    end
  end
end
