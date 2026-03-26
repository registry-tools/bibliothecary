# frozen_string_literal: true

require "json"

module Bibliothecary
  module Parsers
    class Haxelib
      include Bibliothecary::Analyser

      def self.file_patterns
        ["haxelib.json"]
      end

      def self.mapping
        {
          match_filename("haxelib.json") => {
            kind: "manifest",
            parser: :parse_manifest,
            can_have_lockfile: false,
          },
        }
      end

      def self.parse_manifest(file_contents, options: {})
        manifest = JSON.parse(file_contents)
        dependencies = manifest.fetch("dependencies", {}).map do |name, requirement|
          Dependency.new(
            name: name,
            requirement: requirement,
            type: "runtime",
            source: options.fetch(:filename, nil),
            platform: platform_name
          )
        end
        url = manifest["url"]
        repository_url = URLNormalizer.forge_url?(url) ? URLNormalizer.normalize(url) : nil
        ParserResult.new(dependencies: dependencies, project_name: manifest["name"], git_info: HostedGitInfo.new(repository_url).to_h)
      end
    end
  end
end
