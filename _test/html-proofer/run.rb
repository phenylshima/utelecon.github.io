# frozen_string_literal: true

require 'html_proofer'
require 'json'
require 'fileutils'
require_relative 'check/utelecon_domain'
require_relative '../utils/config'

class CustomRunner < HTMLProofer::Runner
  URL_TYPES = %i[external internal realpath].freeze

  def initialize(src, opts)
    super
    CustomRunner.superclass.const_set(:URL_TYPES, URL_TYPES)
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
end

SITE = CONFIG.path(:html_proofer, :code, :site)

proofer = CustomRunner.new([SITE], {
                             type: :directory,
                             disable_external: true,
                             ignore_missing_alt: true,
                             checks: %w[Links Images Scripts UteleconDomain],
                             swap_urls: {
                               %r{^https?://utelecon\.adm\.u-tokyo\.ac\.jp} => '',
                               %r{^https?://utelecon\.github\.io} => ''
                             }
                           })
proofer.run

OUTPUTCONFIG = CONFIG.partial(:html_proofer, :output, :files)

File.open(OUTPUTCONFIG.path(:failures), 'w') do |file|
  failures = proofer.failed_checks.map do |failure|
    f = failure
        .instance_variables
        .map { |sym| [sym[1..].intern, failure.instance_variable_get(sym)] }
        .to_h
    f[:realpath] = proofer.realpath(f[:path])
    f[:path] = f[:path][SITE.size..] if !f[:path].nil? && f[:path].start_with?(SITE)
    f
  end
  file.write(JSON[failures])
end

File.open(OUTPUTCONFIG.path(:external), 'w') do |file|
  external = proofer.instance_variable_get('@external_urls')
  file.write(JSON[external])
end
