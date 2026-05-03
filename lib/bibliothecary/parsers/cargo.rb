# frozen_string_literal: true

module Bibliothecary
  module Parsers
    class Cargo
      include Bibliothecary::Analyser

      def self.file_patterns
        ["Cargo.toml", "Cargo.lock"]
      end

      def self.mapping
        {
          match_filename("Cargo.toml") => {
            kind: "manifest",
            parser: :parse_manifest,
          },
          match_filename("Cargo.lock") => {
            kind: "lockfile",
            parser: :parse_lockfile,
          },
        }
      end


      def self.parse_manifest(file_contents, options: {})
        manifest = Tomlrb.parse(file_contents)

        parsed_dependencies = []

        manifest.fetch_values("dependencies", "dev-dependencies").each_with_index do |deps, index|
          parsed_dependencies << deps.map do |name, requirement|
            dep_resolved_source = nil
            if requirement.respond_to?(:fetch)
              if requirement["git"]
                git_url = requirement["git"]
                normalized_base = URLNormalizer.normalize(git_url)
                dep_git = HostedGitInfo.new(normalized_base)
                dep_git.committish = requirement["rev"] || requirement["tag"] || requirement["branch"]

                full_url = dep_git.committish ? "#{normalized_base}##{dep_git.committish}" : normalized_base
                dep_resolved_source = if dep_git.valid?
                  ResolvedSource.git(url: full_url, host: dep_git.host, namespace: dep_git.namespace, project: dep_git.project, committish: dep_git.committish)
                else
                  ResolvedSource.git(url: full_url)
                end

                requirement = git_url
              elsif requirement["version"]
                requirement = requirement["version"]
              else
                next
              end
            end

            Dependency.new(
              name: name,
              requirement: requirement,
              type: index.zero? ? "runtime" : "development",
              source: options.fetch(:filename, nil),
              platform: platform_name,
              resolved_source: dep_resolved_source
            )
          end
        end

        dependencies = parsed_dependencies.flatten.compact
        git_info = HostedGitInfo.new(URLNormalizer.normalize(manifest.dig("package", "repository")))
        ParserResult.new(dependencies: dependencies, project_name: manifest.dig("package", "name"), git_info: git_info.to_h)
      end

      def self.parse_lockfile(file_contents, options: {})
        dependencies = []
        # Split into [[package]] blocks and extract fields from each
        file_contents.split(/\[\[package\]\]/).drop(1).each do |block|
          name = block[/name\s*=\s*"([^"]+)"/, 1]
          version = block[/version\s*=\s*"([^"]+)"/, 1]
          source = block[/source\s*=\s*"([^"]+)"/, 1]
          checksum = block[/checksum\s*=\s*"([^"]+)"/, 1]

          next if source.nil? # Likely the root package itself, or a local/workspace package

          git_source = if source.start_with?("git+")
            normalized = URLNormalizer.normalize(source)
            info = HostedGitInfo.new(normalized)
            if info.valid?
              ResolvedSource.git(url: normalized, host: info.host, namespace: info.namespace, project: info.project, committish: info.committish)
            else
              ResolvedSource.git(url: normalized)
            end
          end

          # Skip packages without a registry source or git source (local/workspace packages)
          next if !source.start_with?("registry+") && git_source.nil?

          dependencies << Dependency.new(
            name: name,
            requirement: version,
            type: "runtime",
            source: options.fetch(:filename, nil),
            platform: platform_name,
            integrity: checksum ? "sha256=#{checksum}" : nil,
            resolved_source: git_source
          )
        end
        ParserResult.new(dependencies: dependencies)
      end
    end
  end
end
