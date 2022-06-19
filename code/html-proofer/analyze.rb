# frozen_string_literal: true

require 'set'
require 'json'
require 'cgi/escape'
require 'uri'
require 'erb'
require_relative './message'

def remove_en_index_ext(url, prefix = '', en = true)
  arr = url.split('/')
  arr.shift if arr[0] == ''
  arr.shift if arr[0] == '.'
  arr.shift if arr[0] == prefix
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
    category = failure[:@check_name]
    key = find_message(category, failure[:@description])

    case key
    when :unknown_category
      puts "Unknown Category: #{failure[:@check_name]}"
    when :unknown_message
      puts "Unknown Message: #{failure[:@check_name]}/#{failure[:@description]}"
    when :internal_not_exist
      path = remove_en_index_ext(failure[:@path])
      url = remove_en_index_ext(get_arguments(category, key, failure[:@description])[0])
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

class Report
  def initialize
    @render_id = 0
    @id_hash = {}.compare_by_identity
    @id_seq = 0
  end

  def generate_summary(stats)
    ERB.new(
      File.read('code/html-proofer/template/summary.erb'),
      trim_mode: '-'
    ).result(binding)
  end

  def generate_text(report_grouped)
    ERB.new(
      File.read('code/html-proofer/template/detail.erb'),
      trim_mode: '-'
    ).result(binding)
  end

  def render(file, bind, vars = {})
    path = File.join('code/html-proofer/template/components/', "_#{file}.erb")
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

File.open('_report/all.json', 'r') do |file|
  report = JSON.parse(file.read, symbolize_names: true)
               .map do |f|
    f[:@check_name] = f[:@check_name].intern
    f[:@path] = remove_en_index_ext(f[:@path], '_site', false)
    f
  end
  report_grouped = group_failures(report)
  stats = report_grouped.transform_values(&:size)
  p stats

  md = Report.new

  md_summary = md.generate_summary(stats)
  File.write('_report/summary.md', md_summary)

  md_text = md.generate_text(report_grouped)

  File.write('_report/report.md', md_text.byteslice(0, 65_000).scrub(''))
end
