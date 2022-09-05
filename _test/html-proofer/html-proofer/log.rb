# frozen_string_literal: true

require 'html_proofer'

module CustomHTMLProofer
  class Log < HTMLProofer::Log
    def debug?
      true
    end
  end
end
