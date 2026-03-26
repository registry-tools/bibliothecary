# frozen_string_literal: true

require "uri"

module Bibliothecary
  module URLNormalizer
    FORGE_DOMAINS = %r{github\.com|gitlab\.com|bitbucket\.org|codeberg\.org|sr\.ht}

    def self.normalize(url)
      return nil if url.nil? || url.strip.empty?

      url = url.strip

      # Handle SSH URLs first, because they are not really URIs. fix_ssh requires no scheme prefix be present, and it
      # doesn't matter anyway since we're after the host and path parts
      if url.start_with?("git@")
        url = fix_ssh(url)
      elsif url.start_with?("ssh://")
        url = fix_ssh(url[6..])
      elsif url.start_with?("git+ssh://")
        url = fix_ssh(url[10..])
      end

      return nil if url.index(":").nil? # Not a valid URL if it doesn't contain a colon by this point

      url = fix_protocol(url)

      url = url.sub(%r{^git://}, "https://")
      url = url.sub(%r{^git\+https://}, "https://")
      url = url.sub(%r{\.git$}, "")

      url
    end

    def self.forge_url?(url)
      return false if url.nil?

      url.match?(FORGE_DOMAINS)
    end

    def self.fix_ssh(url)
      host_part, path_part = url.split(%r{[:/]}, 2)
      _, host = host_part.split("@", 2)
      port = ""
      if path_part.match?(%r{^\d+})
        # There's a port specified, so split on the first slash instead of the first colon
        port = ":#{path_part.to_i}"
        path_part = path_part.split("/", 2)[1]
      end

      url = "https://#{host}#{port}/#{path_part}"
    end

    def self.fix_protocol(url)
      first_colon = url.index(":")
      if url[first_colon..first_colon + 2] == "://"
        # URL already has a protocol
        return url
      end

      "#{url[0..first_colon]}//#{url[first_colon + 1..]}"
    end
  end
end
