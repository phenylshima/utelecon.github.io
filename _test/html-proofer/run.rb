# frozen_string_literal: true

require 'json'
require 'fileutils'

require_relative 'html-proofer/runner'
require_relative 'check/utelecon_domain'
require_relative '../utils/config'

SITE = CONFIG.path(:html_proofer, :code, :site)
OUTPUTCONFIG = CONFIG.partial(:html_proofer, :output, :files)

proofer = CustomHTMLProofer::Runner.new(
  [SITE],
  {
    type: :directory,
    disable_external: ARGV[0] != '--external',
    ignore_missing_alt: true,
    ignore_urls: [%r{^https://docs.google.com/forms/d/e/1FAIpQLSdEantPHma0G5NhkaSS_28MwfoTQNw9ic9TD8tb-snpcOZVjQ/.*$}],
    checks: %w[Links Images Scripts UteleconDomain],
    swap_urls: {
      %r{^https?://utelecon\.adm\.u-tokyo\.ac\.jp} => '',
      %r{^https?://utelecon\.github\.io} => ''
    },
    cache: {
      timeframe: {
        external: '30d'
      },
      cache_file: OUTPUTCONFIG.get(:cache),
      storage_dir: File.dirname(OUTPUTCONFIG.path(:cache))
    }
  }
)

proofer.run

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
