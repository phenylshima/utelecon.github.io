# frozen_string_literal: true

require 'html_proofer'

# warn urls which include telecon's domain(utelecon.adm.u-tokyo.ac.jp)
class UteleconDomain < HTMLProofer::Check
  def run
    @html.css('a, link, source').each do |node|
      @link = create_element(node)
      next if @link.ignore?

      if %r{https:?//utelecon\.adm\.u-tokyo\.ac\.jp/}.match?(@link.link_attribute)
        add_failure("linking to #{@link.link_attribute}, which includes utelecon's domain(use relative or absolute path instead).")
      end
    end
  end

  def short_name
    'Utelecon Domain'
  end
end
