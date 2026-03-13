# frozen_string_literal: true

require "yaml"

module Bibliothecary
  module Parsers
    class Pub
      include Bibliothecary::Analyser

      def self.file_patterns
        ["pubspec.yaml", "pubspec.lock"]
      end

      def self.mapping
        {
          match_filename("pubspec.yaml", case_insensitive: true) => {
            kind: "manifest",
            parser: :parse_yaml_manifest,
          },
          match_filename("pubspec.lock", case_insensitive: true) => {
            kind: "lockfile",
            parser: :parse_yaml_lockfile,
          },
        }
      end


      def self.parse_yaml_manifest(file_contents, options: {})
        manifest = YAML.load file_contents
        dependencies = map_dependencies(manifest, "dependencies", "runtime", options.fetch(:filename, nil)) +
                       map_dependencies(manifest, "dev_dependencies", "development", options.fetch(:filename, nil))

        repo = manifest["repository"]
        repo ||= manifest["homepage"] if URLNormalizer.forge_url?(manifest["homepage"])
        repository_url = URLNormalizer.normalize(repo)

        ParserResult.new(dependencies: dependencies, project_name: manifest["name"], repository_url: repository_url)
      end

      def self.parse_yaml_lockfile(file_contents, options: {})
        manifest = YAML.load file_contents
        dependencies = manifest.fetch("packages", []).map do |name, dep|
          Dependency.new(
            name: name,
            requirement: dep["version"],
            type: "runtime",
            source: options.fetch(:filename, nil),
            platform: platform_name
          )
        end
        ParserResult.new(dependencies: dependencies)
      end
    end
  end
end
