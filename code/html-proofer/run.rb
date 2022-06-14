# frozen_string_literal: true

require 'html_proofer'
require 'json'
require 'fileutils'
require_relative 'check/utelecon_domain'

class CustomRunner < HTMLProofer::Runner
  def report_failed_checks; end

  def check_parsed(path, source)
    should_check = true
    @html.xpath('/html/head/comment()').each do |node|
      text = node.text.strip
      next unless text.start_with?('html-proofer:')

      parse = /^html-proofer:(?<bool>true|false)$/.match(text)
      next if parse.nil? || !parse.names.include?('bool')

      should_check = false if parse[:bool] != 'true'

      break
    end
    if should_check
      super
    else
      { internal_urls: {}, external_urls: {}, failures: [] }
    end
  end
end

proofer = CustomRunner.new(['./_site'], {
                             type: :directory,
                             disable_external: true,
                             ignore_missing_alt: true,
                             checks: %w[Links Images Scripts UteleconDomain],
                             swap_urls: {
                               %r{^https://utelecon\.adm\.u-tokyo\.ac\.jp} => '/'
                             }
                           })
proofer.run

FileUtils.remove_entry_secure('_report', **{ force: true })
FileUtils.makedirs('_report')

File.open('_report/all.json', 'w') do |file|
  failures = proofer.failed_checks.map do |failure|
    failure
      .instance_variables
      .map { |sym| [sym, failure.instance_variable_get(sym)] }
      .to_h
  end
  file.write(JSON[failures])
end
