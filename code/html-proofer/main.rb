require 'html_proofer'
require 'json'
require 'fileutils'

# Write errors to file
class LogToFile < HTMLProofer::Log
  # init
  def initialize(log_level)
    super(log_level)
    FileUtils.remove_entry_secure('_report', **{ force: true })
    FileUtils.makedirs('_report')
  end

  # log
  def log(level, message)
    case level
    when :main
      File.open('_report/main.json',
                File.exist?('_report/main.json') ? 'a' : 'w') do |file|
        file.write(message)
      end
    when :sub
      File.open('_report/sub.json',
                File.exist?('_report/sub.json') ? 'a' : 'w') do |file|
        file.write(message)
      end
    else
      super(level, message)
    end
  end
end

# Export Report in the form of JUnit XML
class MochaJSON < HTMLProofer::Reporter
  # Generate Report
  def report
    groups = failures.map { |f| f[1] }.flatten.group_by do |failure|
      path = remove_en_index_ext(failure.path, '_site')
      desc = /^internally linking to (?<url>.*), which does not exist$/.match(failure.description)

      if !desc.nil? && path == remove_en_index_ext(desc[:url]) # Translation not exist
        :sub_skip
      elsif /^internally linking to a directory .* without trailing slash$/.match?(failure.description)
        :sub_pass
      elsif /^.* is not an HTTPS link$/.match?(failure.description)
        :sub_error
      else
        :main_error
      end
    end

    testsuites_sub = create_report(passes: groups[:sub_pass], pending: groups[:sub_skip], failures: groups[:sub_error])
    testsuites_main = create_report(failures: groups[:main_error])

    @logger.log(:sub, JSON[testsuites_sub])
    @logger.log(:main, JSON[testsuites_main])
  end

  def create_report(report)
    {
      stats: {
        duration: 0
      },
      passes: report.key?(:passes) ? to_json(report[:passes]) : [],
      pending: report.key?(:pending) ? to_json(report[:pending]) : [],
      failures: report.key?(:failures) ? to_json(report[:failures]) : []
    }
  end

  # Converts array of failure to xml
  def to_json(failures)
    return [] if failures.nil?

    failures.map do |failure|
      path = remove_en_index_ext(failure.path, '_site', false)
      {
        err: { message: failure.description, stack: failure.description },
        file: path,
        title: failure.check_name,
        fullTitle: failure.check_name
      }
    end
  end

  # Removes prefix, extension, '/en/', and the 'index' at the last
  def remove_en_index_ext(url, prefix = '', en = true)
    arr = url.split('/')
    arr.shift if arr[0] == ''
    arr.shift if arr[0] == '.'
    arr.shift if arr[0] == prefix
    arr.shift if en && arr[0] == 'en'
    last_arr = arr[-1].split('.')
    last_arr.pop if last_arr.size >= 2
    last = last_arr.join('.')
    last = '' if last == 'index'
    arr[-1] = last
    arr.pop if arr[-1] == ''
    arr.prepend('')
    arr.join('/')
  end
end

proofer = HTMLProofer.check_directory('./_site', {
                                        disable_external: true,
                                        ignore_missing_alt: true,
                                        swap_urls: { %r{^https://utelecon\.adm\.u-tokyo\.ac\.jp} => '/' }
                                      })
proofer.reporter = MochaJSON.new(logger: LogToFile.new(:info))
proofer.run
