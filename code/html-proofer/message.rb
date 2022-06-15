# frozen_string_literal: true

# Messages that may be emitted from html-proofer
MESSAGES = {
  'Favicon': {
    favicon_not_exist: ['internal favicon ', ' does not exist'],
    favicon_not_provided: ['no favicon provided']
  },
  'Images': {
    image_filename: ['image has a terrible filename (', ')'],
    image_no_src: ['image has no src or srcset attribute'],
    image_not_exist: ['internal image ', ' does not exist'],
    image_no_alt: ['image ', ' does not have an alt attribute'],
    image_http: ['image ', ' uses the http scheme']
  },
  'Links': {
    link_empty_hash: ['linking to internal hash #, which points to nowhere'],
    link_missing_ref: ["'", "' tag is missing a reference"],
    link_dir_no_slash: ['internally linking to a directory ', ' without trailing slash'],
    link_http: [nil, ' is not an HTTPS link'],
    link_no_email: [nil, ' contains no email address'],
    link_invalid_email: [nil, ' contains an invalid email address'],
    link_no_phone: [nil, ' contains no phone number'],
    link_invalid_url: [nil, ' is an invalid URL'],
    link_cors: ['SRI and CORS not provided in: ', nil],
    link_missing_integrity: ['Integrity is missing in: ', nil],
    link_cors_external: ['CORS not provided for external resource in: ', nil]
  },
  'OpenGraph': {
    opengraph_no_content: ['open graph has no content attribute'],
    opengraph_empty_content: ['open graph content attribute is empty'],
    opengraph_not_exist: ['internal open graph ', ' does not exist'],
    opengraph_invalid_url: [nil, ' is an invalid URL']
  },
  'Scripts': {
    script_no_src: ['script is empty and has no src attribute'],
    script_no_ref: ['internal script reference ', ' does not exist'],
    script_cors: ['SRI and CORS not provided in: ', nil],
    script_missing_integrity: ['Integrity is missing in: ', nil],
    script_cors_external: ['CORS not provided for external resource in: ', nil]
  },
  'Links > External': {
    external_fail: ['External link ', ' failed', nil],
    external_hash: ['External link ', ' failed: ', " exists, but the hash '", "' does not"],
    external_timeout: ['External link ', ' failed: got a time out (response code ', ')'],
    external_connection: ['External link ', ' failed with something very wrong.', nil],
    external_invalid_url: [nil, ' is an invalid URL']
  },
  'Links > Internal': {
    internal_not_exist: ['internally linking to ', ', which does not exist'],
    internal_hash: ['internally linking to ', "; the file exists, but the hash '", "' does not"]
  },
  'Utelecon Domain': {
    domain: ['linking to ', ", which includes utelecon's domain(use relative or absolute path instead)."]
  }
}.freeze

MESSAGE_SKIP = %i[
  link_http
  link_dir_no_slash
].freeze

# Finds message from MESSAGES
def find_message(category, msg)
  return :unknown_category unless MESSAGES.key?(category)

  filtered = MESSAGES[category].select do |_k, v|
    (v.first.nil? || msg.start_with?(v.first)) \
      && (v.last.nil? || msg.end_with?(v.last)) \
      && v.all? { |elem| elem.nil? || msg.include?(elem) } # naive but enough for MESSAGES
  end

  return :unknown_message if filtered.size.zero?

  filtered.max_by { |_k, v| v.size }[0]
end

# Gets arguments
def get_arguments(category, key, msg)
  cat = MESSAGES[category]
  return nil if cat.nil?

  list = cat[key]
  return nil if list.nil?

  list.each_with_object([msg]) do |v, current|
    next if v.nil?

    current.concat(current.pop.split(v, 2).reject { |elem| elem.size.zero? })
  end
end
