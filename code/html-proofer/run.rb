# frozen_string_literal: true

require 'html_proofer'
require 'json'
require 'fileutils'

class CustomRunner < HTMLProofer::Runner
  def report_failed_checks; end
end

proofer = CustomRunner.new(['./_site'], {
                             type: :directory,
                             disable_external: true,
                             ignore_missing_alt: true,
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
