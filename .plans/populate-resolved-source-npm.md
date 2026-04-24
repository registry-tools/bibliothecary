# Plan: Extend NPM Ecosystem Lockfile Parsers with Resolved Source Information

## Context

An ingest service uses bibliothecary to extract dependency edges between repositories. Currently, lockfile parsers extract package name, version, and integrity — but not **where** each dependency was actually fetched from. Adding resolved source information (registry tarball URL, git repo, or local path) enables stronger repo-to-repo linking heuristics. This change extends `Dependency` with a new `resolved_source` field and populates it across all NPM ecosystem lockfile parsers.

## Approach: New `resolved_source` field on `Dependency`

Add `resolved_source` as a **new field** alongside the existing `git_info`. The field is a plain hash (consistent with existing `git_info` pattern) with a discriminating `:type` key. Three shapes:

```ruby
# Registry — fetched from a package registry
{ type: :registry, registry_url: "https://registry.npmjs.org", tarball_url: "https://registry.npmjs.org/foo/-/foo-1.0.0.tgz" }

# Git — fetched from a git repository
{ type: :git, url: "https://github.com/vuejs/vue", host: "github.com", namespace: "vuejs", project: "vue", committish: "bb253db..." }

# Local — local path or workspace link
{ type: :local, path: "src/other-package", workspace: false, link: true }
```

**Why not replace `git_info`?** Keeping `git_info` avoids a breaking change for downstream consumers. Parsers will populate **both** fields during this change — `resolved_source` with the new richer data, and `git_info` continuing to work as before for git dependencies. Deprecation of `git_info` is a follow-up.

**`direct` field**: Already exists on `Dependency` (currently always nil for lockfiles). This change populates it where the lockfile format allows.

## Implementation Steps

### Step 1: Add `resolved_source` to `Dependency`

**File:** `lib/bibliothecary/dependency.rb`

- Add `:resolved_source` to `FIELDS` (after `:git_info`)
- Add `resolved_source: nil` keyword arg to `initialize`
- Add `@resolved_source = resolved_source` assignment

### Step 2: Add shared utility methods to NPM parser

**File:** `lib/bibliothecary/parsers/npm.rb`

Add three new class methods:

1. **`resolve_source(resolved_url, link: false, registry_config: nil, package_name: nil)`** — Central dispatch:
   - If `link` is true → `{ type: :local, path: resolved_url, workspace: false, link: true }`
   - If starts with `file:` → `{ type: :local, path: ..., workspace: false, link: false }`
   - If starts with `link:` → `{ type: :local, path: ..., workspace: false, link: true }`
   - If starts with `workspace:` → `{ type: :local, path: ..., workspace: true, link: false }`
   - If `might_be_git_url?` → call `parse_git_resolved`
   - Otherwise → call `parse_registry_resolved`, passing `registry_config` and `package_name`

2. **`parse_git_resolved(url_string)`** — Uses existing `normalize_npm_url` + `HostedGitInfo`:
   - Returns `{ type: :git, url: normalized, host:, namespace:, project:, committish: }` (nil keys omitted)

3. **`parse_registry_resolved(resolved_url, registry_config: nil, package_name: nil)`** — Parses registry tarball URLs:
   - If `resolved_url` is present: `URI.parse` the URL, extract hostname → `registry_url: "https://#{host}"`, `tarball_url: resolved_url`
   - If `resolved_url` is nil/empty but `registry_config` is present: infer `registry_url` from config (see Step 2b)
   - Returns `nil` only if both URL and config are absent

### Step 2b: Registry config file parsing and integration

**Goal:** When a lockfile doesn't contain full tarball URLs (e.g. pnpm) or when we want the implied registry for a dependency, consult config files that live alongside the lockfile.

**Config file priority by lockfile type:**
| Lockfile | Config files considered (in order) |
|---|---|
| `package-lock.json` (npm) | `.npmrc` |
| `yarn.lock` v1 | `.npmrc` |
| `yarn.lock` v2 | `.yarnrc.yml` |
| `pnpm-lock.yaml` | `.npmrc` |
| `bun.lock` | `bunfig.toml`, then `.npmrc` |

**Unified registry config structure** (output of all config parsers):
```ruby
{
  default_registry: "https://registry.npmjs.org",  # nil if not configured
  scoped_registries: {                              # empty hash if none
    "@myorg" => "https://npm.myorg.com",
    "@other" => "https://other.registry.dev"
  }
}
```

**New class methods:**

1. **`parse_npmrc_registries(contents)`** — Parse `.npmrc` INI-style format:
   - `registry=URL` → `default_registry`
   - `@scope:registry=URL` → `scoped_registries["@scope"]`
   - Ignore auth lines (`_authToken`, `_auth`, `_password`, `username`, `email`)
   - Ignore environment variable references (`${...}`) — leave `registry_url` as-is with the variable unexpanded
   - Strip trailing slashes from URLs for consistency

2. **`parse_yarnrc_yml_registries(contents)`** — Parse `.yarnrc.yml` YAML:
   - `npmRegistryServer: URL` → `default_registry`
   - `npmScopes.SCOPE.npmRegistryServer: URL` → `scoped_registries["@SCOPE"]` (yarn omits the `@` prefix in scope keys)
   - Uses `YAML.safe_load` (already available in npm.rb for pnpm parsing)

3. **`parse_bunfig_toml_registries(contents)`** — Parse `bunfig.toml`:
   - `[install] registry = "URL"` or `registry = { url = "URL" }` or `registry = "https://user:pass@host"` → `default_registry` (extract just scheme+host, strip credentials)
   - `[install.scopes] SCOPE = "URL"` or `SCOPE = { url = "URL" }` → `scoped_registries["@SCOPE"]`
   - Uses a lightweight TOML parser (add `toml-rb` gem, or parse manually since the structure is simple)
   - Strip credentials from URLs (user:pass@)

4. **`registry_url_for(package_name, registry_config)`** — Look up registry for a package:
   - If `package_name` starts with `@scope/`, check `scoped_registries["@scope"]`
   - Fall back to `default_registry`
   - Fall back to `nil` (unknown)

**Integration with the parsing pipeline:**

**File:** `lib/bibliothecary/parsers/npm.rb`

- Add `.npmrc`, `.yarnrc.yml`, `bunfig.toml` to `file_patterns` and `mapping` with `kind: "config"` and `parser: nil`
- Override `analyse_file_info(file_info_list, options: {})`:
  1. Separate config files (`kind == "config"`) from parseable files
  2. Group config files by directory (`File.dirname(info.relative_path)`)
  3. For each parseable lockfile, find config files in the same directory
  4. Based on lockfile type, select and parse the appropriate config file(s) → build `registry_config`
  5. Pass `registry_config` via `options[:registry_config]` when calling `analyse_contents_from_info`
  6. Return only analyses for non-config files (config files don't produce dependency lists)

**In `parse_registry_resolved`:** When `resolved_url` is nil/empty, use `registry_url_for(package_name, registry_config)` to infer `registry_url`. The `tarball_url` remains nil in this case.

### Step 3: Update `parse_package_lock_v2` (npm v2+/v3)

**Direct detection:** Extract direct dep names from `manifest.dig("packages", "")` — union of `dependencies`, `devDependencies`, `optionalDependencies` keys → `Set`. A dep is direct if its bare name (last `node_modules/` segment) is in this set AND it has no nested `node_modules/` in its key path (i.e., `name.scan("node_modules/").count == 1`).

**Resolved source:** Call `resolve_source(dep["resolved"], link: dep.fetch("link", false), registry_config: options[:registry_config], package_name: name)` for each entry. Pass result as `resolved_source:` to `Dependency.new`.

**Keep existing `git_info:`** — continue calling `git_info(dep["resolved"])&.to_h` as before.

### Step 4: Update `parse_package_lock_v1` / `parse_package_lock_deps_recursively`

**Direct detection:** Depth 1 = `direct: true`, depth > 1 = `direct: false`.

**Resolved source:** Call `resolve_source(url_source, registry_config: options[:registry_config], package_name: name)` where `url_source` is already computed. Pass as `resolved_source:`.

### Step 5: Update `parse_v1_yarn_lock`

**Extract `resolved` URL:** Enhance the regex or add a second scan to capture the `resolved "URL"` line from each block. The current regex only captures header + version.

Approach: After the existing scan, do a block-based extraction. Split content on top-level headers (unindented lines ending with `:`), then within each block extract `resolved "..."`. Add `:resolved` to the returned hash.

**In `parse_yarn_lock`:** Call `resolve_source(dep[:resolved], registry_config: options[:registry_config], package_name: dep[:name])` and pass as `resolved_source:`.

**Direct detection via `package.json`:** Accept `options[:package_json]` (a pre-parsed JSON hash). If provided, build direct set from `dependencies` + `devDependencies` + `optionalDependencies` keys. Set `direct: true/false/nil` accordingly.

### Step 6: Update `parse_v2_yarn_lock`

**Extract `resolved` URL:** Add extraction of the `resolution:` line from the block body: `body[/resolution:\s*"?([^"\n]+)"?/, 1]`. This contains the package resolution string.

**In `parse_yarn_lock`:** Same `resolve_source` (with `registry_config` and `package_name`) and `package_json` handling as v1.

### Step 7: Update pnpm parsers (v5, v6, v9)

**Direct detection (all versions):**
- v5/v6: Top-level `dependencies`/`devDependencies` keys → direct set
- v9: `importers["."]["dependencies"]`/`["devDependencies"]` keys → direct set (already built as `dependency_mapping`)

**Resolved source:** pnpm doesn't store tarball URLs. For packages with `resolution.integrity`, use `registry_url_for(package_name, options[:registry_config])` to infer the registry → `{ type: :registry, registry_url: inferred_or_nil, tarball_url: nil }`. For packages with `resolution.tarball`, parse the URL to determine if it's a git source (e.g., GitHub codeload) or registry tarball. For packages with `resolution.type: "git"` or git-style resolution, emit git source. This is where config-based registry inference is most valuable since pnpm lockfiles never include tarball URLs for registry packages.

### Step 8: Update `parse_bun_lock`

**Direct detection:** Already has `dev_deps` set. Build `direct_deps` from `manifest.dig("workspaces", "", "dependencies")` + `devDependencies` keys.

**Resolved source:** `info[1]` in the bun.lock array contains the tarball URL or is absent for local deps. Call `resolve_source(info[1], registry_config: options[:registry_config], package_name: name)`.

### Step 9: Update test expectations

**File:** `spec/parsers/npm_spec.rb`

For each existing test assertion that constructs `Dependency.new(...)`:
- Add `resolved_source:` with the expected hash based on the fixture data
- Add `direct:` where the format supports it

**New test cases to add:**
- Registry resolved source extraction from npm v2 lockfile (verify `tarball_url` from `find-versions` fixture)
- Git resolved source from yarn v1 (`yarn-with-git-repo` fixture — verify host/namespace/project/committish)
- Local resolved source from npm v3 (`npm-local-file` fixture — verify `link: true`)
- Direct vs transitive in npm v2 (`find-versions` is direct, `semver-regex` under `find-versions/node_modules/` is transitive)
- Direct detection with optional `package_json` for yarn
- pnpm direct detection using importers section
- Edge case: `resolve_source(nil)` returns nil
- Edge case: registry URL with `registry.yarnpkg.com` hostname

**Registry config test cases (new):**
- `parse_npmrc_registries`: default registry, scoped registry, mixed, empty, comments
- `parse_yarnrc_yml_registries`: `npmRegistryServer`, `npmScopes` with multiple scopes, empty
- `parse_bunfig_toml_registries`: string registry, object registry, scoped registries, credentials stripped
- `registry_url_for`: scoped match, unscoped fallback to default, no config → nil
- `analyse_file_info` integration: lockfile + .npmrc in same directory → `registry_config` flows to parser
- pnpm with .npmrc scoped registry: verify `registry_url` is inferred for `@scope/pkg`

### Step 10: Verification

Run `bundle exec rspec` — all 392+ existing tests must pass, plus new test cases.

## Critical Files

| File | Change |
|------|--------|
| `lib/bibliothecary/dependency.rb` | Add `resolved_source` field |
| `lib/bibliothecary/parsers/npm.rb` | Add utility + config-parsing methods, override `analyse_file_info`, update all 8 parser methods |
| `spec/parsers/npm_spec.rb` | Update assertions, add new test cases |
| `spec/fixtures/` | Add `.npmrc`, `.yarnrc.yml`, `bunfig.toml` fixture files for config parsing tests |

## Existing Utilities to Reuse

- `HostedGitInfo` (`lib/bibliothecary/hosted_git_info.rb`) — git URL → `{ host, namespace, project, committish }`
- `URLNormalizer.normalize` (`lib/bibliothecary/url_normalizer.rb`) — SSH/git protocol normalization
- `NPM.normalize_npm_url` — github:/gitlab:/bitbucket: shorthand expansion
- `NPM.might_be_git_url?` — git URL detection heuristic
- `NPM.git_info` — existing git info extraction (will be preserved alongside new code)

## Edge Cases

- **Missing `resolved` field**: If no config file either → `resolved_source: nil`. If config available → infer `registry_url` from config, `tarball_url: nil`.
- **pnpm no tarball URL**: Use config-based inference. `{ type: :registry, registry_url: inferred_or_nil, tarball_url: nil }`.
- **Peer doppelgangers in pnpm**: Version suffix stripping already handles these. Same resolved source.
- **Merged ranges in yarn**: Single resolved version per block. One `resolved_source` applies.
- **`registry.yarnpkg.com` vs `registry.npmjs.org`**: Store hostname as-is. Don't normalize between them.
- **Ancient lockfiles (v0/missing version)**: Falls into v1 path. `resolved` may be absent → nil.
- **Scoped packages in tarball URLs**: `URI.parse` handles `@scope/` in paths correctly.
- **Config files with env vars**: Store the URL as-is with `${VAR}` unexpanded. Consumers can decide whether to resolve.
- **Credentials in URLs**: Strip `user:pass@` from registry URLs in bunfig.toml (and .npmrc if present as `//host/:_authToken`). Only store scheme+host.
- **No config file present**: Gracefully degrade — `registry_config` is nil, all behavior falls back to URL-based extraction only.
- **Config file in wrong directory**: Only consider config files in the same directory as the lockfile (not parent directories). We parse what's in the repo snapshot, not the user's global config.
- **TOML parsing**: The `tomlrb` gem is already loaded for toml parsing
