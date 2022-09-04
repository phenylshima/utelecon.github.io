TYPHOEUS_DEFAULTS = {
  followlocation: true,
  headers: {
    'User-Agent' => 'Mozilla/5.0 (compatible; HTML Proofer/4.3.0; +https://github.com/gjtorikian/html-proofer)',
    'Accept' => 'application/xml,application/xhtml+xml,text/html;q=0.9, text/plain;q=0.8,image/png,*/*;q=0.5'
  },
  connecttimeout: 10,
  timeout: 30
}.freeze

require 'typhoeus'

hydra = Typhoeus::Hydra.new({ max_concurrency: 50 })

request1 = Typhoeus::Request.new('http://example.com/', TYPHOEUS_DEFAULTS)
request2 = Typhoeus::Request.new('https://example.com/', TYPHOEUS_DEFAULTS)

request1.on_complete { |response| print '1:', response.return_code, "\n" }
request2.on_complete { |response| print '2:', response.return_code, "\n" }
hydra.queue(request1)
hydra.queue(request2)

hydra.run
