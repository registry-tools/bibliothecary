# frozen_string_literal: true

require "uri"

module Bibliothecary
  module URLNormalizer
    FORGE_DOMAINS = %r{github\.com|gitlab\.com|bitbucket\.org|codeberg\.org|sr\.ht}

    def self.normalize(url)
      return nil if url.nil? || url.strip.empty?

      url = url.strip
      # Handle GitHub shorthand like "owner/repo"
      if github_shorthand?(url)
        url = "github:#{url}"
      end

      url = fix_maven_scm(url)

      # Handle SSH URLs first, because they are not really URIs
      if url.start_with?("ssh://")
        url = fix_ssh(url[6..])
      elsif url.start_with?("git@")
        url = fix_ssh(url)
      end

      url = fix_protocol(url)
      url = fix_shorthand(url)

      url = url.sub(%r{^git://}, "https://")
      url = url.sub(%r{^git\+https://}, "https://")
      url = url.sub(/\.git$/, "")

      url
    end

    def self.forge_url?(url)
      return false if url.nil?

      url.match?(FORGE_DOMAINS)
    end

    def self.fix_ssh(url)
      host_part, path_part = url.split(":", 2)
      _, host = host_part.split("@", 2)

      port = ""
      if path_part.match?(%r{^\d+})
        # There's a port specified, so split on the first slash instead of the first colon
        port = ":#{path_part.to_i}"
        path_part = path_part.split("/", 2)[1]
      end

      url = "https://#{host}#{port}/#{path_part}"
    end

    def self.fix_maven_scm(url)
      if url.start_with?("scm:git:")
        url = url[8..]
      elsif url.start_with?("scm:local|")
        url = "file://#{url[10..]}"
      end
      url
    end

    def self.fix_shorthand(url)
      if url.start_with?("github://")
        url = "https://github.com/#{url[9..]}"
      elsif url.start_with?("gitlab://")
        url = "https://gitlab.com/#{url[9..]}"
      elsif url.start_with?("bitbucket://")
        url = "https://bitbucket.org/#{url[12..]}"
      elsif url.start_with?("gist://")
        url = "https://gist.github.com/#{url[7..]}"
      end

      url
    end

    def self.fix_protocol(url)
      first_colon = url.index(":")
      if url[first_colon..first_colon + 2] == "://"
        # URL already has a protocol
        return url
      end

      "#{url[0..first_colon]}//#{url[first_colon + 1..]}"
    end

    def self.github_shorthand?(url)
      /^[\w-]+\/[\w-]+$/.match?(url)
    end
  end
end
