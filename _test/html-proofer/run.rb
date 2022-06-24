# frozen_string_literal: true

require 'html_proofer'
require 'json'
require 'fileutils'
require_relative 'check/utelecon_domain'

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
end

proofer = CustomRunner.new(['./_site'], {
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

# FileUtils.remove_entry_secure('_report', **{ force: true })
FileUtils.makedirs('_test/result')

File.open('_test/result/all.json', 'w') do |file|
  failures = proofer.failed_checks.map do |failure|
    failure
      .instance_variables
      .map { |sym| [sym, failure.instance_variable_get(sym)] }
      .to_h
  end
  file.write(JSON[failures])
end

File.open('_test/result/external.json', 'w') do |file|
  external = proofer.instance_variable_get('@external_urls')
  file.write(JSON[external])
end

File.open('_test/result/path.json', 'w') do |file|
  path_dict = proofer.instance_variable_get('@realpath_urls').transform_values { |v| v[0] }
  file.write(JSON[path_dict])
end
