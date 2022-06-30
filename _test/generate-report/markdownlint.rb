# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'base'
require_relative '../utils/config'

# Failure from markdownlint
class MarkdownlintFailure < CommonFailure
  def valid?
    !path.size.zero?
  end

  def path
    @data[:path]
  end

  def start_line
    @data[:lineNumber]
  end

  def end_line
    @data[:lineNumber]
  end

  def start_column
    return nil unless @data[:errorRange].is_a?(Array)

    @data[:errorRange].min
  end

  def end_column
    return nil unless @data[:errorRange].is_a?(Array)

    @data[:errorRange].max
  end

  def message
    "#{@data[:ruleDescription]}(#{@data[:ruleInformation]})\n#{@data[:errorDetail]}"
  end

  def title
    "#{@data[:ruleNames][0]} - #{@data[:ruleDescription]}"
  end

  def raw_details
    YAML.dump(@data)
  end
end

# Report generator for markdownlint
class MarkdownlintReporter < Reporter
  TEMPLATECONFIG = CONFIG.partial(:generate_report, :code, :templates)
  MARKDOWNLINTCONFIG = CONFIG.partial(:markdownlint, :output, :files)

  def initialize(changed_files)
    super({
      title: 'Markdown Check',
      summary: TEMPLATECONFIG.path(:markdownlint, :summary),
      annotation_failures: :main,
      changed_files: changed_files,
      erb_context: ERBContext.new(TEMPLATECONFIG.path(:components))
    })
  end

  def generate_report
    file = File.read(MARKDOWNLINTCONFIG.path(:report))
    report = JSON
             .parse(file, symbolize_names: true)
             .map { |d| MarkdownlintFailure.new(d) }
    report_grouped = {
      main: report
    }
    super(report_grouped)
  end
end
