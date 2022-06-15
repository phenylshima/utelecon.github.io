# frozen_string_literal: true

require 'set'
require 'json'
require 'cgi/escape'
require 'uri'
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
    if key == :unknown_category
      puts "Unknown Category: #{failure[:@check_name]}"
    elsif key == :unknown_message
      puts "Unknown Message: #{failure[:@check_name]}/#{failure[:@description]}"
    end
    if key == :internal_not_exist
      path = remove_en_index_ext(failure[:@path])
      url = remove_en_index_ext(get_arguments(category, key, failure[:@description])[0])
      next :translation if path == url
      next :translation if path == URI.decode_www_form_component(url)
    end
    if MESSAGE_SKIP.include?(key)
      :skip
    else
      :main
    end
  end
end

class Report
  def generate_summary(id, stats)
    <<~"EOS"
      ![](https://img.shields.io/static/v1?color=#{stats.key?(:main) ? 'red' : 'green'}\
      &label=tests&message=\
      #{stats.key?(:main) ? stats[:main] : 0}%20failed%2C%20\
      #{stats.key?(:skip) ? stats[:skip] : 0}%20skipped\
      )

      ![](https://img.shields.io/static/v1?color=lightgray\
      &label=translation&message=\
      #{stats.key?(:translation) ? stats[:translation] : 0}%20missing\
      )

      | Report | Failure count |
      | -- | -- |
      | [❌ Failure](##{id(id, 0)}) | #{stats.key?(:main) ? stats[:main] : 0} |
      | [🌏 Translation](##{id(id, 2)}) | #{stats.key?(:translation) ? stats[:translation] : 0} |
      | [✖️ Skipped](##{id(id, 1)}) | #{stats.key?(:skip) ? stats[:skip] : 0} |
    EOS
  end

  def failures_to_markdown(id, failures)
    grouped = failures.group_by { |f| f[:@path] }
    stats = grouped.transform_values do |v|
      v.group_by { |f| f[:@check_name] }.transform_values(&:size)
    end
    cols = Hash[
      stats
           .each_with_object(Set[]) { |(_k, v), o| o.merge(v.keys) }
           .map
           .with_index { |c, idx| [c, idx] }
    ]

    md = String.new
    md << table(id, stats, cols, 'Failure')
    md << "\n"
    md << with_title(id, grouped) do |_k, v, idx|
      v.group_by { |f| f[:@check_name] }.each_with_object(String.new) do |(name, fails), codes|
        codes << title(4, name, id, idx, cols[name])
        codes << "\n"
        tmp = fails.each_with_object(String.new) do |failure, c|
          c << "- #{failure[:@description]}"
          c << " (L#{failure[:@line]})" unless failure[:@line].nil?
          unless failure[:@content].nil? || failure[:@content].strip.size.zero?
            c << indent(1,
                        "`#{content_sanitize(failure[:@content])}`")
          end
          c << "\n"
        end
        codes << indent(1, tmp)
        codes << "\n"
      end
    end
    md << "\n"
  end

  def translation_to_markdown(failures)
    "\n- #{failures.map { |f| f[:@path] }.join("\n- ")}\n"
  end

  def indent(level, content)
    content.gsub(/^/, '  ' * level)
  end

  def details(summary, content)
    "<details><summary>#{summary}</summary>\n#{content}\n</details>"
  end

  def table(id, hash, cols, topleft)
    table = "\n| #{topleft} | #{cols.keys.join(' | ')} |\n|#{' -- |' * (cols.size + 1)}\n"
    hash.each_with_index do |(k, v), idx|
      col_texts = cols.map do |c, col_id|
        v.key?(c) ? "[#{v[c]}](##{id(id, idx, col_id)})" : ''
      end
      table << "| [#{k}](##{id(id, idx)}) | #{col_texts.join(' | ')} |\n"
    end
    table
  end

  def with_title(id, hash)
    codes = String.new
    hash.each_with_index do |(k, v), idx|
      codes << title(3, k, id, idx)
      codes << "\n\n"
      codes << yield(k, v, idx)
      codes << "\n\n"
    end
    codes
  end

  def title(level, text, *ids)
    id = id(ids)
    "<h#{level} id='#{id}'><a href='##{id}'>#{text}</a></h#{level}>\n"
  end

  def id(*ids)
    ids.flatten.each_with_object('i'.dup) do |i, str|
      str << "-#{i}"
    end
  end

  def content_sanitize(content)
    CGI.escapeHTML(content.gsub("\n", '\n'))
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

  md_summary = String.new
  md_summary << md.generate_summary(0, stats)
  File.write('_report/summary.md', md_summary)

  md_text = String.new

  md_text << md.title(2, 'Failure', 0, 0)
  md_text << if report_grouped[:main].nil?
               '✔️ All checks passed!'
             else
               md.failures_to_markdown(1, report_grouped[:main])
             end

  md_text << md.title(2, 'Translation', 0, 2)
  md_text << if report_grouped[:translation].nil?
               '✔️ All pages are translated!'
             else
               md.details('Pages without translation', md.translation_to_markdown(report_grouped[:translation]))
             end

  md_text << md.title(2, 'Skipped', 0, 1)
  md_text << if report_grouped[:skip].nil?
               'No skipped issues.'
             else
               md.details('Skipped Issues', md.failures_to_markdown(2, report_grouped[:skip]))
             end

  File.write('_report/report.md', md_text.byteslice(0, 65_000).scrub(''))
end
