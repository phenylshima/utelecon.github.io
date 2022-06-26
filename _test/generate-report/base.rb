# frozen_string_literal: true

require 'erb'
require 'set'
require 'cgi/escape'

# Provides context(binding) for ERB rendering
class ERBContext
  def initialize(component_path)
    @component_path = component_path
    @render_id = 0
    @id_hash = {}.compare_by_identity
    @id_seq = 0
  end

  def context
    binding
  end

  def render(file, bind, vars = {})
    path = File.join(@component_path, "_#{file}.erb")
    erb = ERB.new(File.read(path), eoutvar: "res_#{@render_id += 1}", trim_mode: '-')
    vars.each do |k, v|
      bind.local_variable_set(k, v)
    end
    erb.result(bind)
  end

  def id(obj)
    @id_hash[obj] = "id-#{@id_seq += 1}" unless @id_hash.key?(obj)
    @id_hash[obj]
  end

  def content_sanitize(content)
    return nil if content.nil?

    escaped = CGI.escapeHTML(content.gsub("\n", '\n'))
    if escaped.strip.size.zero?
      nil
    else
      escaped
    end
  end
end

# Represents a failure in a common format
class CommonFailure
  def initialize(data)
    @data = data
  end

  def valid?
    false
  end

  def path
    ''
  end

  def start_line
    0
  end

  def end_line
    0
  end

  def start_column; end

  def end_column; end

  def annotaion_level
    'failure'
  end

  def message
    'Something went wrong'
  end

  def title; end
  def raw_details; end
end

# options
#   title: Report title(String)
#   summary: Path to summary template(String)
#   text: Path to text template(String)
#   annotation_failures: Failure category used to generate annotation(Symbol[])
#   changed_files: List of changed files(String[])
#   erb_context: Context for ERB(ERBContext)
#   failure_converter: Class extending CommonFailure(<CommonFailure)
# report_grouped: Hash of kind of Failure(String) and list of Failure(Failure[])

# Class to generate report
class Reporter
  def initialize(options)
    @options = options
  end

  def generate_report(report_grouped)
    {
      title: @options[:title].nil? ? 'Test Report' : @options[:title],
      summary: generate_summary(report_grouped).byteslice(0, 65_535).scrub(''),
      text: generate_text(report_grouped).byteslice(0, 65_535).scrub(''),
      annotations: generate_annotations(report_grouped)
    }
  end

  def generate_summary(report_grouped)
    return '' if @options[:summary].nil?

    ERB.new(
      File.read(@options[:summary]),
      trim_mode: '-'
    ).result(erb_context(report_grouped))
  end

  def generate_text(report_grouped)
    return '' if @options[:text].nil?

    ERB.new(
      File.read(@options[:text]),
      trim_mode: '-'
    ).result(erb_context(report_grouped))
  end

  def generate_annotations(report_grouped)
    if report_grouped[@options[:annotation_failures]].nil? \
       || @options[:changed_files].nil? \
       || @options[:failure_converter].nil?
      return []
    end

    filtered = report_grouped[@options[:annotation_failures]]
               .map { |failure| @options[:failure_converter].new(failure) }
               .select do |failure|
      failure.valid? && @options[:changed_files].include?(failure.path)
    end

    filtered[0..50].map do |failure|
      {
        path: failure.path,
        start_line: failure.start_line,
        end_line: failure.end_line,
        start_column: failure.start_column,
        end_column: failure.end_column,
        annotation_level: failure.annotaion_level,
        message: failure.message,
        title: failure.title,
        raw_details: failure.raw_details
      }.reject { |_k, v| v.nil? }
    end
  end

  def erb_context(report_grouped)
    context = @options[:erb_context].context
    context.local_variable_set(:stats, report_grouped.transform_values(&:size))
    context.local_variable_set(:report_grouped, report_grouped)
    context
  end
end
