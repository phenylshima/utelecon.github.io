# frozen_string_literal: true

require 'json'

require_relative 'html_proofer'
require_relative 'markdownlint'
require_relative '../utils/config'

REPORTCONFIG = CONFIG.partial(:generate_report, :output, :files)
CHANGEDFILESCONFIG = CONFIG.partial(:changed_files, :output, :files)

changed_files = JSON.parse(File.read(CHANGEDFILESCONFIG.path(:changed_files)))

File.write(
  REPORTCONFIG.path(:html_proofer),
  JSON[HTMLProoferReporter.new(changed_files).generate_report]
)

File.write(
  REPORTCONFIG.path(:markdownlint),
  JSON[MarkdownlintReporter.new(changed_files).generate_report]
)
