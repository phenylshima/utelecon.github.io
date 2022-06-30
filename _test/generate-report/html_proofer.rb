# frozen_string_literal: true

require 'uri'

require_relative 'base'
require_relative 'message'
require_relative '../utils/config'

# Failure from HTMLProofer
class HTMLProoferFailure < CommonFailure
  def initialize(data)
    data[:check_name] = data[:check_name].intern
    super(data)
  end

  def valid?
    !path.size.zero?
  end

  def path
    return '' if @data[:realpath].nil? || @data[:realpath][0].nil?

    @data[:realpath][0]
  end

  def message
    @data[:description]
  end

  def title
    @data[:check_name]
  end

  def to_markdown
    sanitized = content_sanitize(@data[:content])
    "#{super}#{sanitized.nil? || sanitized.strip.size.zero? ? nil : " `#{sanitized}`"}"
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

MESSAGE_SKIP = CONFIG.get(:html_proofer, :code, :skip).map(&:intern)

# ERBContext for html-proofer(We need this to pass MESSAGE_SKIP to ERB templates)
class HTMLProoferERBContext < ERBContext; end

# Report generator for html-proofer
class HTMLProoferReporter < Reporter
  TEMPLATECONFIG = CONFIG.partial(:generate_report, :code, :templates)
  HTMLPROOFERCONFIG = CONFIG.partial(:html_proofer, :output, :files)

  def initialize(changed_files)
    super({
      title: 'HTML Check',
      summary: TEMPLATECONFIG.path(:html_proofer, :summary),
      text: TEMPLATECONFIG.path(:html_proofer, :text),
      annotation_failures: :main,
      changed_files: changed_files,
      erb_context: HTMLProoferERBContext.new(TEMPLATECONFIG.path(:components))
    })
  end

  def generate_report
    file = File.read(HTMLPROOFERCONFIG.path(:failures))
    report = JSON.parse(file, symbolize_names: true)
                 .map { |f| HTMLProoferFailure.new(f) }
    report_grouped = group_failures(report)
    super(report_grouped)
  end

  def remove_en_index_ext(url, en = true)
    arr = url.split('/').reject { |e| e.strip.empty? }
    arr.shift if arr[0] == '.'
    arr.shift if en && arr[0] == 'en'

    return '/' if arr.size.zero?

    last_arr = arr[-1].split('.')
    last_arr.pop if last_arr.size >= 2
    last = last_arr.join('.')
    last = '' if last == 'index'
    arr[-1] = last
    arr.pop if arr[-1] == '' && arr.size >= 2
    arr.prepend('')
    arr.join('/')
  end

  def group_failures(report)
    report.group_by do |failure|
      category = failure.title
      key = find_message(category, failure.message)

      case key
      when :unknown_category
        puts "Unknown Category: #{failure.title}"
      when :unknown_message
        puts "Unknown Message: #{failure.title}/#{failure.message}"
      when :internal_not_exist
        path = remove_en_index_ext(failure.path)
        url = remove_en_index_ext(get_arguments(category, key, failure.message)[0])
        next :translation if path == url
        next :translation if path == URI.decode_www_form_component(url)
      when :flag
        next :flag
      end
      if MESSAGE_SKIP.include?(key)
        :skip
      else
        :main
      end
    end
  end
end
