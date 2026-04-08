require 'yaml'

module Bibliothecary
  module Parsers
    class Jenkins
      include Bibliothecary::Analyser

      def self.file_patterns
        ["Jenkinsfile"]
      end

      def self.mapping
        {
          match_filenames("Jenkinsfile") => {
            kind: 'manifest',
            parser: :parse_manifest,
            can_have_lockfile: false
          },
        }
      end

      def self.parse_manifest(file_contents, options: {})
        ParserResult.new(dependencies: [])
      end
    end
  end
end