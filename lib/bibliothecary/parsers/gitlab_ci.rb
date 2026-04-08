require 'yaml'

module Bibliothecary
  module Parsers
    class GitlabCi
      include Bibliothecary::Analyser

      def self.file_patterns
        ["gitlab-ci.yml"]
      end

      def self.mapping
        {
          match_filenames("gitlab-ci.yml") => {
            kind: 'manifest',
            parser: :parse_manifest,
            can_have_lockfile: false
          },
        }
      end

      def self.parse_manifest(file_contents, options: {})
        # Depedencies in Gitlab CI take the form of include: component:, but the entire tree of includes can be complex to resolve and may be remote.
        ParserResult.new(dependencies: [])
      end
    end
  end
end