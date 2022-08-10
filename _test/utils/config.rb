# frozen_string_literal: true

require 'yaml'
require 'fileutils'

class Config
  def initialize(data, base = File.join(__dir__, '../../'))
    @data = data
    @base = base
  end

  def partial(*symbols)
    current = @data
    base = [@base]
    symbols.each do |s|
      break if current.nil?

      base << current[:base] if current.is_a?(Hash) && current.key?(:base)
      current = current[s]
    end
    path = File.join(base)
    Config.new(current, path)
  end

  def get(*symbols)
    if symbols.size.zero?
      @data
    else
      partial(*symbols).get
    end
  end

  def path(*symbols)
    if symbols.size.zero?
      if @data.is_a?(String)
        path = File.join(@base, @data)
        FileUtils.makedirs(File.dirname(path)) if path.is_a?(String)
        path
      else
        @data
      end
    else
      partial(*symbols).path
    end
  end
end

f = File.open(File.join(__dir__, '../globalConfig.yml'), 'r')
CONFIG = Config.new(YAML.safe_load(f, symbolize_names: true))
f.close
