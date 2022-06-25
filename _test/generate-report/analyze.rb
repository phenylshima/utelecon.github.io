# frozen_string_literal: true

require 'set'
require 'json'
require 'cgi/escape'
require 'uri'
require 'erb'
require 'fileutils'
require_relative './message'
require_relative '../utils/config'

HTMLPROOFERCONFIG = CONFIG.partial(:html_proofer, :output, :files)
CHANGEDFILESCONFIG = CONFIG.partial(:changed_files, :output, :files)
REPORTCONFIG = CONFIG.partial(:generate_report, :output, :files)
TEMPLATECONFIG = CONFIG.partial(:generate_report, :code, :templates)
MESSAGE_SKIP = CONFIG.get(:html_proofer, :code, :skip).map(&:intern)

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
    category = failure[:check_name]
    key = find_message(category, failure[:description])

    case key
    when :unknown_category
      puts "Unknown Category: #{failure[:check_name]}"
    when :unknown_message
      puts "Unknown Message: #{failure[:check_name]}/#{failure[:description]}"
    when :internal_not_exist
      path = remove_en_index_ext(failure[:path])
      url = remove_en_index_ext(get_arguments(category, key, failure[:description])[0])
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

def get_annotations(failures)
  changed_files = JSON.parse(File.read(CHANGEDFILESCONFIG.path(:changed_files)))
  filtered = failures.select do |failure|
    !failure[:realpath].nil? && changed_files.include?(failure[:realpath][0])
  end
  filtered[0..50].map do |failure|
    {
      path: failure[:realpath][0],
      start_line: 0,
      end_line: 0,
      annotation_level: 'failure',
      message: failure[:description],
      title: failure[:check_name]
    }
  end
end

class Report
  def initialize
    @render_id = 0
    @id_hash = {}.compare_by_identity
    @id_seq = 0
  end

  def generate_summary(stats)
    ERB.new(
      File.read(TEMPLATECONFIG.path(:summary)),
      trim_mode: '-'
    ).result(binding)
  end

  def generate_text(report_grouped)
    ERB.new(
      File.read(TEMPLATECONFIG.path(:text)),
      trim_mode: '-'
    ).result(binding)
  end

  def render(file, bind, vars = {})
    path = File.join(TEMPLATECONFIG.path(:components), "_#{file}.erb")
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

File.open(HTMLPROOFERCONFIG.path(:failures), 'r') do |file|
  report = JSON.parse(file.read, symbolize_names: true)
               .map do |f|
    f[:check_name] = f[:check_name].intern
    f[:path] = remove_en_index_ext(f[:path], false)
    f
  end
  report_grouped = group_failures(report)
  stats = report_grouped.transform_values(&:size)
  p stats

  md = Report.new

  report = {
    title: 'HTML Link/Image/Script Check',
    summary: md.generate_summary(stats).byteslice(0, 65_535).scrub(''),
    text: md.generate_text(report_grouped).byteslice(0, 65_535).scrub(''),
    annotations: get_annotations(report_grouped[:main])
  }

  File.write(REPORTCONFIG.path(:html_proofer), JSON[report])
end
