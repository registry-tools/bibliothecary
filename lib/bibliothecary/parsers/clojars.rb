module Bibliothecary
  module Parsers
    class Clojars
      include Bibliothecary::Analyser

      # Matches individual dependency: [name "version"]
      # Name can be like: org.clojure/clojure, cheshire, ring/ring-defaults
      DEPENDENCY_REGEXP = %r{\[([a-zA-Z0-9_./\-]+)\s+"([^"]+)"\]}

      def self.file_patterns
        ["project.clj"]
      end

      def self.mapping
        {
          match_filename("project.clj") => {
            kind: "manifest",
            parser: :parse_manifest,
            can_have_lockfile: false,
          },
        }
      end


      def self.parse_manifest(file_contents, options: {})
        source = options.fetch(:filename, "project.clj")
        deps = []

        project_name = file_contents.match(/defproject\s+([^\s]+)/)&.captures&.first

        # Find the :dependencies section and extract deps
        # Look for :dependencies followed by a vector of vectors
        if (deps_section = file_contents[/:dependencies\s*\[.*?\]\]/m])
          deps_section.scan(DEPENDENCY_REGEXP) do |name, version|
            deps << Dependency.new(
              platform: platform_name,
              name: name,
              requirement: version,
              type: "runtime",
              source: source
            )
          end
        end

        ParserResult.new(dependencies: deps, project_name: project_name)
      end
    end
  end
end
