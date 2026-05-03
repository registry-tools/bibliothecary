# frozen_string_literal: true

require "json"
require "uri"

module Bibliothecary
  module Parsers
    class NPM
      include Bibliothecary::Analyser

      # Max depth to recurse into the "dependencies" property of package-lock.json
      PACKAGE_LOCK_JSON_MAX_DEPTH = 10

      def self.file_patterns
        ["package.json", "package-lock.json", "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml", "pnpm-workspace.yaml", "bun.lock", "npm-ls.json", ".npmrc", ".yarnrc.yml", "bunfig.toml"]
      end

      def self.mapping
        {
          match_filename("package.json") => {
            kind: "manifest",
            parser: :parse_manifest,
          },
          match_filename("yarn.lock") => {
            kind: "lockfile",
            parser: :parse_yarn_lock,
          },
          match_filename("package-lock.json") => {
            kind: "lockfile",
            parser: :parse_package_lock,
          },
          match_filename("pnpm-lock.yaml") => {
            kind: "lockfile",
            parser: :parse_pnpm_lock,
          },
          match_filename("pnpm-workspace.yaml") => {
            kind: "manifest",
            parser: :parse_pnpm_workspace,
            related_to: ["lockfile"],
          },
          match_filename("npm-ls.json") => {
            kind: "lockfile",
            parser: :parse_ls,
          },
          match_filename("npm-shrinkwrap.json") => {
            kind: "lockfile",
            parser: :parse_shrinkwrap,
          },
          match_filename("bun.lock") => {
            kind: "lockfile",
            parser: :parse_bun_lock,
          },
          match_filename(".npmrc") => {
            kind: "config",
            parser: nil,
          },
          match_filename(".yarnrc.yml") => {
            kind: "config",
            parser: nil,
          },
          match_filename("bunfig.toml") => {
            kind: "config",
            parser: nil,
          },
        }
      end


      # Override analyse_file_info to extract registry config from config files
      # and pass it to lockfile parsers in the same directory.
      def self.analyse_file_info(file_info_list, options: {})
        matching_info = file_info_list.select(&method(:match_info?))

        # Separate config files from parseable files
        config_files, parseable_files = matching_info.partition do |info|
          determine_kind_from_info(info) == "config"
        end

        # Group config files by directory
        configs_by_dir = config_files.group_by { |info| File.dirname(info.relative_path) }

        parseable_files.flat_map do |info|
          dir = File.dirname(info.relative_path)
          lockfile_name = File.basename(info.relative_path)
          dir_configs = configs_by_dir[dir] || []

          registry_config = build_registry_config(lockfile_name, dir_configs)
          merged_options = registry_config ? options.merge(registry_config: registry_config) : options

          analyse_contents_from_info(info, options: merged_options)
            .merge(related_paths: related_paths(info, parseable_files))
        end
      end

      # Build a registry config hash from config files appropriate for a given lockfile type.
      def self.build_registry_config(lockfile_name, config_infos)
        config_map = config_infos.each_with_object({}) do |info, map|
          map[File.basename(info.relative_path)] = info.contents
        end

        case lockfile_name
        when "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml"
          parse_npmrc_registries(config_map[".npmrc"]) if config_map[".npmrc"]
        when "yarn.lock"
          if config_map[".yarnrc.yml"]
            parse_yarnrc_yml_registries(config_map[".yarnrc.yml"])
          elsif config_map[".npmrc"]
            parse_npmrc_registries(config_map[".npmrc"])
          end
        when "bun.lock"
          if config_map["bunfig.toml"]
            parse_bunfig_toml_registries(config_map["bunfig.toml"])
          elsif config_map[".npmrc"]
            parse_npmrc_registries(config_map[".npmrc"])
          end
        end
      end

      def self.parse_package_lock(file_contents, options: {})
        manifest = JSON.parse(file_contents)
        source = options.fetch(:filename, nil)
        registry_config = options[:registry_config]
        # https://docs.npmjs.com/cli/v9/configuring-npm/package-lock-json#lockfileversion
        dependencies = if manifest["lockfileVersion"].to_i <= 1
                         # lockfileVersion 1 uses the "dependencies" object
                         parse_package_lock_v1(manifest, source, registry_config: registry_config)
                       else
                         # lockfileVersion 2 has backwards-compatability by including both "packages" and the legacy "dependencies" object
                         # lockfileVersion 3 has no backwards-compatibility and only includes the "packages" object
                         parse_package_lock_v2(manifest, source, registry_config: registry_config)
                       end
        ParserResult.new(dependencies: dependencies)
      end

      class << self
        # "package-lock.json" and "npm-shrinkwrap.json" have same format, so use same parsing logic
        alias parse_shrinkwrap parse_package_lock
      end

      def self.parse_package_lock_v1(manifest, source = nil, registry_config: nil)
        parse_package_lock_deps_recursively(manifest.fetch("dependencies", []), source, registry_config: registry_config)
      end

      def self.parse_package_lock_v2(manifest, source = nil, registry_config: nil)
        # Build direct deps set from the root package entry
        root_pkg = manifest.dig("packages", "") || {}
        direct_names = %w[dependencies devDependencies optionalDependencies].flat_map { |k| (root_pkg[k] || {}).keys }.to_set

        # "packages" is a flat object where each key is the installed location of the dep, e.g. node_modules/foo/node_modules/bar.
        manifest
          .fetch("packages")
          # there are a couple of scenarios where a package's name won't start with node_modules
          #   1. name == "", this is the lockfile's package itself
          #   2. when a package is a local path dependency, it will appear in package-lock.json twice.
          #      * One occurrence has the node_modules/ prefix in the name (which we keep)
          #      * The other occurrence's name is the path to the local dependency (which has less information, and is duplicative, so we discard)
          .select { |name, _dep| name.start_with?("node_modules") }
          .map do |pkg_path, dep|
            # check if the name property is available and differs from the node modules location
            # this indicates that the package has been aliased
            node_module_name = pkg_path.split("node_modules/").last
            name_property = dep["name"]
            if !name_property.nil? && node_module_name != name_property
              name = name_property
              original_name = node_module_name
            else
              name = node_module_name
            end

            is_link = dep.fetch("link", false)
            # A dep is direct if its bare name is in the root deps and it's at the top level
            # (only one "node_modules/" segment in the path, meaning no nesting)
            is_direct = direct_names.include?(node_module_name) && pkg_path.scan("node_modules/").count == 1

            Dependency.new(
              name: name,
              original_name: original_name,
              requirement: dep["version"],
              original_requirement: original_name.nil? ? nil : dep["version"],
              type: dep.fetch("dev", false) || dep.fetch("devOptional", false) ? "development" : "runtime",
              direct: is_direct,
              local: is_link,
              source: source,
              platform: platform_name,
              integrity: dep["integrity"],
              git_info: git_info(dep["resolved"])&.to_h,
              resolved_source: resolve_source(dep["resolved"], link: is_link, registry_config: registry_config, package_name: name),
            )
          end
      end

      def self.parse_package_lock_deps_recursively(dependencies, source = nil, depth = 1, registry_config: nil)
        dependencies.flat_map do |name, requirement|
          type = requirement.fetch("dev", false) ? "development" : "runtime"
          version = requirement.key?("from") ? requirement["from"][/#(?:semver:)?v?(.*)/, 1] : nil
          version ||= requirement["version"].split("#").last
          child_dependencies = if depth >= PACKAGE_LOCK_JSON_MAX_DEPTH
                                 []
                               else
                                 parse_package_lock_deps_recursively(requirement.fetch("dependencies", []), source, depth + 1, registry_config: registry_config)
                               end

          url_source = requirement.key?("from") ? requirement["from"] : requirement["resolved"]

          [Dependency.new(
            name: name,
            requirement: version,
            type: type,
            direct: depth == 1,
            source: source,
            platform: platform_name,
            integrity: requirement["integrity"],
            git_info: git_info(url_source)&.to_h,
            resolved_source: resolve_source(url_source, registry_config: registry_config, package_name: name),
          )] + child_dependencies
        end
      end

      def self.might_be_git_url?(requirement)
        requirement.start_with?("git", "github:", "gitlab:", "bitbucket:") || requirement.match(/\.git(#|$)/)
      end

      def self.git_info(requirement)
        if requirement && !requirement.start_with?("@") && might_be_git_url?(requirement)
          # Likely a github source or URL of some kind. Look for clues that this is a git URL
          return HostedGitInfo.new(normalize_npm_url(requirement))
        end
      end

      def self.parse_manifest(file_contents, options: {})
        # on ruby 3.2 we suddenly get this JSON error, so detect and return early: "package.json: unexpected token at ''"
        return ParserResult.new(dependencies: []) if file_contents.empty?

        manifest = JSON.parse(file_contents)

        raise "appears to be a lockfile rather than manifest format" if manifest.key?("lockfileVersion")

        dependencies = manifest.fetch("dependencies", [])
          .reject { |name, _requirement| name.start_with?("//") } # Omit comment keys. They are valid in package.json: https://groups.google.com/g/nodejs/c/NmL7jdeuw0M/m/yTqI05DRQrIJ
          .map do |name, requirement|
            # check to see if this is an aliased package name
            # example: "alias-package-name": "npm:actual-package@^1.1.3"
            if requirement.include?("npm:")
              # the name of the real dependency is contained in the requirement with the version
              requirement.gsub!("npm:", "")
              original_name = name
              name, _, requirement = requirement.rpartition("@")
            end

            Dependency.new(
              name: name,
              original_name: original_name,
              requirement: requirement,
              original_requirement: original_name.nil? ? nil : requirement,
              type: "runtime",
              local: requirement.start_with?("file:"),
              source: options.fetch(:filename, nil),
              platform: platform_name,
              git_info: git_info(requirement)&.to_h,
            )
          end

        dependencies += manifest.fetch("devDependencies", [])
          .reject { |name, _requirement| name.start_with?("//") } # Omit comment keys. They are valid in package.json: https://groups.google.com/g/nodejs/c/NmL7jdeuw0M/m/yTqI05DRQrIJ
          .map do |name, requirement|
            Dependency.new(
              name: name,
              requirement: requirement,
              type: "development",
              local: requirement.start_with?("file:"),
              source: options.fetch(:filename, nil),
              platform: platform_name,
              git_info: git_info(requirement)&.to_h,
            )
          end

        ParserResult.new(
          dependencies: dependencies,
          project_name: manifest["name"],
          git_info: HostedGitInfo.new(normalize_npm_url(manifest["repository"]))&.to_h
        )
      end

      def self.parse_yarn_lock(file_contents, options: {})
        dep_hash = if file_contents.match(/__metadata:/)
                     parse_v2_yarn_lock(file_contents, options.fetch(:filename, nil))
                   else
                     parse_v1_yarn_lock(file_contents, options.fetch(:filename, nil))
                   end

        registry_config = options[:registry_config]

        dependencies = dep_hash.map do |dep|
          is_local = dep[:requirements]&.first&.start_with?("file:")
          resolved_url = dep[:resolved]

          Dependency.new(
            name: dep[:name],
            original_name: dep[:original_name],
            requirement: dep[:version],
            original_requirement: dep[:original_requirement],
            type: nil, # yarn.lock doesn't report on the type of dependency
            local: is_local,
            source: options.fetch(:filename, nil),
            platform: platform_name,
            integrity: dep[:integrity],
            resolved_source: resolve_source(resolved_url, registry_config: registry_config, package_name: dep[:name]),
          )
        end
        ParserResult.new(dependencies: dependencies)
      end

      # Returns a hash representation of the deps in yarn.lock, eg:
      # [{
      #   name: "foo",
      #   requirements: [["foo", "^1.0.0"], ["foo", "^1.0.1"]],
      #   version: "1.2.0",
      # }, ...]
      def self.parse_v1_yarn_lock(contents, source = nil)
        deps = []
        # Normalize line endings only if needed
        contents = contents.gsub("\r\n", "\n").gsub("\r", "\n") if contents.include?("\r")

        # Split into blocks by unindented lines (headers) followed by indented content
        # Each block is a header + body
        blocks = contents.split(/\n(?=[^\s#])/)

        blocks.each do |block|
          # Match header and version
          match = block.match(/\A([^\n]+?):\s*\n\s+version "?([^"\n]+)"?/m)
          next unless match

          header = match[1]
          version = match[2]

          # Extract resolved URL if present
          resolved = block[/^\s+resolved "([^"]+)"/, 1]

          # Parse requirements from header (remove quotes and trailing colon)
          requirements = header.gsub(/"/, "").split(",").map(&:strip)

          name, alias_name = yarn_strip_npm_protocol(requirements.first)
          name = name.strip.split(/(?<!^)@/).first
          req_versions = requirements.map { |d| d.strip.split(/(?<!^)@/, 2) }

          deps << {
            name: name,
            original_name: alias_name,
            requirements: req_versions.map { |x| x[1] },
            original_requirement: alias_name.nil? ? nil : version,
            version: version,
            source: source,
            resolved: resolved,
          }
        end
        deps
      end

      def self.parse_v2_yarn_lock(contents, source = nil)
        deps = []
        # Split into blocks by double newlines or by unquoted key lines
        # Each block starts with "package@npm:req": and continues until the next package
        blocks = contents.split(/\n\n+/)

        blocks.each do |block|
          # Match the package header: "package@npm:...":\n  version: ...
          match = block.match(/^"([^"]+)":\s*\n(.+)/m)
          next unless match

          packages_str = match[1]
          body = match[2]

          version = body[/version:\s*([^\n]+)/, 1]
          checksum = body[/checksum:\s*([^\n]+)/, 1]

          # Skip workspace/local packages and patches
          next if version&.include?("use.local") && packages_str.include?("workspace")
          next if packages_str.include?("@patch:")

          packages = packages_str.split(", ")
          # use first requirement's name, assuming that deps will always resolve from deps of the same name
          name, alias_name = yarn_strip_npm_protocol(packages.first.rpartition("@").first)
          requirements = packages.map { |p| p.rpartition("@").last.gsub(/^.*:/, "") }

          # Extract resolution string — yarn v2 uses "package@npm:version" format
          # which isn't a URL but can indicate the protocol (npm, workspace, etc.)
          resolution = body[/resolution:\s*"?([^"\n]+)"?/, 1]
          link_type = body[/linkType:\s*([^\n]+)/, 1]&.strip

          # For yarn v2, determine resolved URL from the resolution string
          resolved_url = nil
          if resolution
            if resolution.include?("@npm:")
              # npm registry package — no direct URL, but we know it's from npm
              resolved_url = nil # will be inferred from registry_config
            elsif resolution.include?("@workspace:")
              resolved_url = "workspace:#{resolution.split("@workspace:").last}"
            elsif resolution.match?(%r{https?://})
              resolved_url = resolution
            end
          end

          deps << {
            name: name,
            original_name: alias_name,
            requirements: requirements,
            original_requirement: alias_name.nil? ? nil : version.to_s,
            version: version.to_s,
            source: source,
            integrity: checksum,
            resolved: resolved_url,
          }
        end
        deps
      end

      def self.parse_v5_pnpm_lock(parsed_contents, source = nil, registry_config: nil)
        dependency_mapping = parsed_contents.fetch("dependencies", {})
          .merge(parsed_contents.fetch("devDependencies", {}))
        direct_names = dependency_mapping.keys.to_set

        parsed_contents["packages"]
          .map do |name_version, details|
            # e.g. "/debug/2.6.9" or "/@babel/types/7.28.1"
            name, _slash, version = name_version.sub(/^\//, "").rpartition("/")

            # e.g. "/debug/2.2.0_supports-color@1.2.0:"
            version = version.split("_", 2)[0]

            # e.g. "alias-package: /zod/3.24.2"
            original_name = nil
            original_requirement = nil
            if (alias_dep = dependency_mapping.find { |_n, v| v.start_with?("/#{name}/") })
              original_name = alias_dep[0]
              original_requirement = alias_dep[1].split("/", 3)[2] # e.g. "/zod/3.24.2"
            end

            is_dev = details["dev"] == true
            is_direct = direct_names.include?(original_name || name)
            resolved_source = pnpm_resolved_source(details, name, registry_config)

            Dependency.new(
              name: name,
              requirement: version,
              original_name: original_name,
              original_requirement: original_requirement,
              type: is_dev ? "development" : "runtime",
              direct: is_direct,
              source: source,
              platform: platform_name,
              integrity: details.dig("resolution", "integrity"),
              resolved_source: resolved_source,
            )
          end
      end

      def self.parse_v6_pnpm_lock(parsed_contents, source = nil, registry_config: nil)
        dependency_mapping = parsed_contents.fetch("dependencies", {})
          .merge(parsed_contents.fetch("devDependencies", {}))
        direct_names = dependency_mapping.keys.to_set

        parsed_contents["packages"]
          .map do |name_version, details|
            # e.g. "/debug@2.6.9:"
            name, version = name_version.sub(/^\//, "").split(/(?<!^)@/, 2)

            # e.g. "debug@2.2.0(supports-color@1.2.0)"
            version = version.split("(", 2).first

            # e.g.
            #  alias-package:
            #    specifier: npm:zod
            #    version: /zod@3.24.2
            original_name = nil
            original_requirement = nil
            if (alias_dep = dependency_mapping.find { |_n, info| info["specifier"] == "npm:#{name}" })
              original_name = alias_dep[0]
              original_requirement = alias_dep[1]["version"].sub(/^\//, "").split("@", 2)[1]
            end

            is_dev = details["dev"] == true
            is_direct = direct_names.include?(original_name || name)
            resolved_source = pnpm_resolved_source(details, name, registry_config)

            Dependency.new(
              name: name,
              requirement: version,
              original_name: original_name,
              original_requirement: original_requirement,
              type: is_dev ? "development" : "runtime",
              direct: is_direct,
              source: source,
              platform: platform_name,
              integrity: details.dig("resolution", "integrity"),
              resolved_source: resolved_source,
            )
          end
      end

      def self.parse_v9_pnpm_lock(parsed_contents, source = nil, registry_config: nil)
        dependencies = parsed_contents.fetch("importers", {}).fetch(".", {}).fetch("dependencies", {})
        dev_dependencies = parsed_contents.fetch("importers", {}).fetch(".", {}).fetch("devDependencies", {})
        dependency_mapping = dependencies.merge(dev_dependencies)
        direct_names = dependency_mapping.keys.to_set
        packages = parsed_contents.fetch("packages", {})

        # "dependencies" is in "packages" for < v9 and in "snapshots" for >= v9
        # as of https://github.com/pnpm/pnpm/pull/7700.
        parsed_contents["snapshots"]
          .map do |name_version, _details|
            # e.g. "debug@2.6.9" or "@babel/types@7.28.1"
            name, version = name_version.split(/(?<!^)@/, 2)

            # e.g. "debug@2.2.0(supports-color@1.2.0)"
            version = version.split("(", 2).first

            # e.g.
            #  alias-package:
            #    specifier: npm:zod
            #    version: zod@3.24.2
            original_name = nil
            original_requirement = nil
            if (alias_dep = dependency_mapping.find { |_n, info| info["specifier"] == "npm:#{name}" })
              original_name = alias_dep[0]
              original_requirement = alias_dep[1]["version"].split("@", 2)[1]
            end

            # TODO: the "dev" field was removed in v9 lockfiles (https://github.com/pnpm/pnpm/pull/7808)
            # The proper way to set this for v9+ is to build a lookup of deps to
            # their "dependencies", and then recurse through each package's
            # parents. If the direct dep(s) that required them are all
            # "devDependencies" then we can consider them "dev == true". This
            # should be done using a DAG data structure, though, to be efficient
            # and avoid cycles.
            is_dev ||= dev_dependencies.any? do |dev_name, dev_details|
              dev_name == name && dev_details["version"] == version
            end

            is_direct = direct_names.include?(original_name || name)

            # In v9, integrity is stored in packages section, not snapshots
            package_key = "#{name}@#{version}"
            pkg_details = packages[package_key] || {}
            integrity = pkg_details.dig("resolution", "integrity")
            resolved_source = pnpm_resolved_source(pkg_details, name, registry_config)

            Dependency.new(
              name: name,
              requirement: version,
              original_name: original_name,
              original_requirement: original_requirement,
              type: is_dev ? "development" : "runtime",
              direct: is_direct,
              source: source,
              platform: platform_name,
              integrity: integrity,
              resolved_source: resolved_source,
            )
          end
      end

      # This method currently has been tested to support:
      #   lockfileVersion: '9.0'
      #   lockfileVersion: '6.0'
      #   lockfileVersion: '5.4'
      def self.parse_pnpm_lock(contents, options: {})
        parsed = YAML.load(contents)
        lockfile_version = parsed["lockfileVersion"].to_i
        source = options.fetch(:filename, nil)
        registry_config = options[:registry_config]

        dependencies = case lockfile_version
                       when 5
                         parse_v5_pnpm_lock(parsed, source, registry_config: registry_config)
                       when 6
                         parse_v6_pnpm_lock(parsed, source, registry_config: registry_config)
                       else # v9+
                         parse_v9_pnpm_lock(parsed, source, registry_config: registry_config)
                       end
        ParserResult.new(dependencies: dependencies)
      end

      def self.parse_pnpm_workspace(contents, options: {})
        parsed = YAML.load(contents)
        source = options.fetch(:filename, nil)

        dependencies = []

        # Parse the default catalog (pnpm 9+)
        if parsed["catalog"].is_a?(Hash)
          parsed["catalog"].each do |name, requirement|
            dependencies << Dependency.new(
              name: name,
              requirement: requirement,
              type: "runtime",
              source: source,
              platform: platform_name,
              git_info: git_info(requirement)&.to_h,
            )
          end
        end

        # Parse named catalogs (pnpm 9+)
        if parsed["catalogs"].is_a?(Hash)
          parsed["catalogs"].each do |_catalog_name, catalog_deps|
            next unless catalog_deps.is_a?(Hash)

            catalog_deps.each do |name, requirement|
              dependencies << Dependency.new(
                name: name,
                requirement: requirement,
                type: "runtime",
                source: source,
                platform: platform_name,
                git_info: git_info(requirement)&.to_h,
              )
            end
          end
        end

        ParserResult.new(dependencies: dependencies)
      end

      def self.parse_ls(file_contents, options: {})
        manifest = JSON.parse(file_contents)

        dependencies = transform_tree_to_array(manifest.fetch("dependencies", {}), options.fetch(:filename, nil))
        ParserResult.new(dependencies: dependencies)
      end

      def self.parse_bun_lock(file_contents, options: {})
        # The stdlib JSON gem 2.8+ supports trailing commas.
        # The Oj gem does not support them as of writing, and will override
        # JSON.parse() if Oj.mimic_json/optimize_rails has been called. Luckily
        # JSON.parser is not overridden by Oj, so use it to call parse directly.
        manifest = JSON.parser.parse(file_contents, allow_trailing_comma: true)
        source = options.fetch(:filename, nil)
        registry_config = options[:registry_config]

        dev_deps = manifest.dig("workspaces", "", "devDependencies")&.keys&.to_set
        all_direct = %w[dependencies devDependencies optionalDependencies].flat_map { |k|
          (manifest.dig("workspaces", "", k) || {}).keys
        }.to_set

        dependencies = manifest.fetch("packages", []).map do |name, info|
          info_name, _, version = info.first.rpartition("@")
          is_local = version&.start_with?("file:")
          is_alias = info_name != name
          tarball_url = info[1].is_a?(String) ? info[1] : nil # second element is the tarball URL when present

          Dependency.new(
            name: info_name,
            original_name: is_alias ? name : nil,
            requirement: version,
            original_requirement: is_alias ? version : nil,
            type: dev_deps&.include?(name) ? "development" : "runtime",
            direct: all_direct.include?(name),
            local: is_local,
            source: source,
            platform: platform_name,
            integrity: info[3],
            git_info: git_info(info[3])&.to_h,
            resolved_source: resolve_source(tarball_url || (is_local ? version : nil), link: false, registry_config: registry_config, package_name: info_name),
          )
        end
        ParserResult.new(dependencies: dependencies)
      end

      def self.lockfile_preference_order(file_infos)
        files = file_infos.each_with_object({}) do |file_info, obj|
          obj[File.basename(file_info.full_path)] = file_info
        end

        if files["npm-shrinkwrap.json"]
          [files["npm-shrinkwrap.json"]] + files.values.reject { |fi| File.basename(fi.full_path) == "npm-shrinkwrap.json" }
        else
          files.values
        end
      end

      def self.normalize_npm_url(repo)
        return nil if repo.nil?

        url = if repo.is_a?(Hash)
                repo["url"]
              else
                str = repo.to_s.strip
                if str.start_with?("github:")
                  "https://github.com/#{str.delete_prefix("github:")}"
                elsif str.start_with?("gitlab:")
                  "https://gitlab.com/#{str.delete_prefix("gitlab:")}"
                elsif str.start_with?("gist:")
                  "https://gist.github.com/#{str.delete_prefix("gist:")}"
                elsif str.start_with?("bitbucket:")
                  "https://bitbucket.org/#{str.delete_prefix("bitbucket:")}"
                elsif str.match?(%r{\Ahttps?://})
                  str
                elsif str.match?(%r{^[\w-]+\/[\w-]+$})
                  # bare "user/repo" shorthand defaults to GitHub
                  "https://github.com/#{str}"
                else
                  str
                end
              end

        URLNormalizer.normalize(url)
      end

        # Parse .npmrc INI-style format for registry configuration.
      def self.parse_npmrc_registries(contents)
        config = { default_registry: nil, scoped_registries: {} }
        return config if contents.nil? || contents.empty?

        contents.each_line do |line|
          line = line.strip
          next if line.empty? || line.start_with?("#") || line.start_with?(";")
          # Skip auth lines
          next if line.match?(/(_authToken|_auth|_password|username|email)\s*=/)

          if (match = line.match(/\A@([^:]+):registry\s*=\s*(.+)\z/))
            scope = "@#{match[1]}"
            url = match[2].strip.chomp("/")
            config[:scoped_registries][scope] = url
          elsif (match = line.match(/\Aregistry\s*=\s*(.+)\z/))
            config[:default_registry] = match[1].strip.chomp("/")
          end
        end
        config
      end

      # Parse .yarnrc.yml YAML format for registry configuration.
      def self.parse_yarnrc_yml_registries(contents)
        config = { default_registry: nil, scoped_registries: {} }
        return config if contents.nil? || contents.empty?

        parsed = YAML.safe_load(contents)
        return config unless parsed.is_a?(Hash)

        if parsed["npmRegistryServer"]
          config[:default_registry] = parsed["npmRegistryServer"].to_s.chomp("/")
        end

        if parsed["npmScopes"].is_a?(Hash)
          parsed["npmScopes"].each do |scope, scope_config|
            next unless scope_config.is_a?(Hash) && scope_config["npmRegistryServer"]
            config[:scoped_registries]["@#{scope}"] = scope_config["npmRegistryServer"].to_s.chomp("/")
          end
        end
        config
      end

      # Parse bunfig.toml for registry configuration.
      def self.parse_bunfig_toml_registries(contents)
        config = { default_registry: nil, scoped_registries: {} }
        return config if contents.nil? || contents.empty?

        parsed = Tomlrb.parse(contents)

        install = parsed["install"]
        return config unless install.is_a?(Hash)

        if install["registry"]
          reg = install["registry"]
          url = reg.is_a?(Hash) ? reg["url"] : reg.to_s
          config[:default_registry] = strip_credentials(url).chomp("/") if url
        end

        if install["scopes"].is_a?(Hash)
          install["scopes"].each do |scope, scope_val|
            url = scope_val.is_a?(Hash) ? scope_val["url"] : scope_val.to_s
            next unless url
            scope_name = scope.start_with?("@") ? scope : "@#{scope}"
            config[:scoped_registries][scope_name] = strip_credentials(url).chomp("/")
          end
        end
        config
      end

      # Look up the registry URL for a package given a registry config.
      def self.registry_url_for(package_name, registry_config)
        return nil unless registry_config && package_name

        if package_name.start_with?("@")
          scope = package_name.split("/", 2).first
          scoped_url = registry_config[:scoped_registries]&.[](scope)
          return scoped_url if scoped_url
        end

        registry_config[:default_registry]
      end

      # Strip credentials (user:pass@) from a URL.
      def self.strip_credentials(url)
        return url unless url
        uri = URI.parse(url)
        uri.user = nil
        uri.password = nil
        uri.to_s
      rescue URI::InvalidURIError
        url
      end

      # Central dispatch for determining the resolved source of a dependency.
      def self.resolve_source(resolved_url, link: false, registry_config: nil, package_name: nil)
        if link
          return { type: :local, path: resolved_url.to_s, workspace: false, link: true }
        end

        if resolved_url.nil? || resolved_url.to_s.empty?
          # No URL — try to infer from registry config
          if registry_config && package_name
            inferred = registry_url_for(package_name, registry_config)
            return { type: :registry, registry_url: inferred, tarball_url: nil } if inferred
          end
          return nil
        end

        resolved_str = resolved_url.to_s

        if resolved_str.start_with?("file:")
          return { type: :local, path: resolved_str.delete_prefix("file:"), workspace: false, link: false }
        end

        if resolved_str.start_with?("link:")
          return { type: :local, path: resolved_str.delete_prefix("link:"), workspace: false, link: true }
        end

        if resolved_str.start_with?("workspace:")
          return { type: :local, path: resolved_str.delete_prefix("workspace:"), workspace: true, link: false }
        end

        if might_be_git_url?(resolved_str)
          return parse_git_resolved(resolved_str)
        end

        parse_registry_resolved(resolved_str, registry_config: registry_config, package_name: package_name)
      end

      # Parse a git resolved URL into a resolved_source hash.
      def self.parse_git_resolved(url_string)
        normalized = normalize_npm_url(url_string)
        info = HostedGitInfo.new(normalized)
        result = { type: :git, url: normalized }
        if info.valid?
          result[:host] = info.host
          result[:namespace] = info.namespace
          result[:project] = info.project
          result[:committish] = info.committish if info.committish
        end
        result
      end

      # Parse a registry tarball URL into a resolved_source hash.
      def self.parse_registry_resolved(resolved_url, registry_config: nil, package_name: nil)
        if resolved_url && !resolved_url.empty?
          begin
            uri = URI.parse(resolved_url)
            registry_url = "#{uri.scheme}://#{uri.host}"
            return { type: :registry, registry_url: registry_url, tarball_url: resolved_url }
          rescue URI::InvalidURIError
            # Fall through to config-based inference
          end
        end

        if registry_config && package_name
          inferred = registry_url_for(package_name, registry_config)
          return { type: :registry, registry_url: inferred, tarball_url: nil } if inferred
        end

        nil
      end

      # Determine the resolved source for a pnpm package based on its resolution details.
      def self.pnpm_resolved_source(details, package_name, registry_config)
        resolution = details["resolution"] || {}

        if resolution["tarball"]
          tarball = resolution["tarball"]
          if might_be_git_url?(tarball)
            return parse_git_resolved(tarball)
          end
          return parse_registry_resolved(tarball, registry_config: registry_config, package_name: package_name)
        end

        if resolution["type"] == "git" || resolution["commit"]
          url = resolution["repo"] || resolution["url"]
          if url
            return parse_git_resolved("#{url}##{resolution["commit"]}")
          end
        end

        # Registry package with integrity but no tarball URL — infer from config
        if resolution["integrity"]
          inferred = registry_url_for(package_name, registry_config)
          return { type: :registry, registry_url: inferred, tarball_url: nil }
        end

        nil
      end

    private_class_method def self.transform_tree_to_array(deps_by_name, source = nil)
        deps_by_name.map do |name, metadata|
          [
            Dependency.new(
              name: name,
              requirement: metadata["version"],
              type: "runtime",
              source: source,
              platform: platform_name
            ),
          ] + transform_tree_to_array(metadata.fetch("dependencies", {}), source)
        end.flatten(1)
      end

      # Yarn package names can be aliased by using the NPM protocol. If a package name includes
      # the NPM protocol then the name following the @npm: protocol identifier is the name of the
      # actual package being imported into the project under a different alias.
      # https://classic.yarnpkg.com/lang/en/docs/cli/add/#toc-yarn-add-alias
      private_class_method def self.yarn_strip_npm_protocol(dep_name)
        if dep_name.include?("@npm:")
          partitions = dep_name.rpartition("@npm:")
          alias_name = partitions.first
          dep_name = partitions.last
        end

        [dep_name, alias_name]
      end
    end
  end
end
