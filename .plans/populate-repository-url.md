# Plan: Populate `repository_url` in All Applicable Parsers

## Context

`ParserResult` has `dependencies` and `project_name` fields. We need a third optional field, `repository_url`, to capture the project's source repository URL from manifest files when one is available. This is ecosystem-specific — each manifest format has different conventions for storing repository information. Use TDD: failing test first, then implementation.

## Requirements

1. **Normalize all URLs** — expand shorthands to full HTTPS URLs, convert `git://` to `https://`, strip `.git` suffixes
2. **Fall back to homepage** when it looks like a repository URL (particularly GitHub URLs)
3. **Batch by tier** to allow parallel coder agents

---

## Step 0: Core Infrastructure

### 0a. `lib/bibliothecary/parser_result.rb`

Add `repository_url` to `FIELDS`, `attr_reader`, and `initialize` (optional kwarg, default `nil`). The existing `eql?`, `to_h`, and `hash` methods iterate over `FIELDS` so they update automatically.

### 0b. `lib/bibliothecary/analyser.rb` (line 21–30)

Add `repository_url: parser_result.repository_url` to the `create_analysis` output hash.

### 0c. URL normalization helper — `lib/bibliothecary/url_normalizer.rb`

Shared module used by all parsers:
```ruby
module Bibliothecary
  module URLNormalizer
    FORGE_DOMAINS = %r{github\.com|gitlab\.com|bitbucket\.org|codeberg\.org|sr\.ht}

    def self.normalize(url)
      return nil if url.nil? || url.strip.empty?
      url = url.strip
      url = url.sub(%r{^git://}, "https://")
      url = url.sub(/\.git$/, "")
      url
    end

    def self.forge_url?(url)
      return false if url.nil?
      url.match?(FORGE_DOMAINS)
    end
  end
end
```

### 0d. Fix all existing tests

Adding `repository_url` to `create_analysis` will break every test that does an exact `eq({...})` match on `analyse_contents` results. Add `repository_url: nil` to every such expectation across all `spec/parsers/*_spec.rb` files. Run `bundle exec rspec` to find and fix all failures before proceeding.

---

## Batch 1: Direct JSON/YAML/TOML Fields (6 parsers)

### npm — `lib/bibliothecary/parsers/npm.rb`, `parse_manifest` (line 137)

**Field:** `manifest["repository"]`
**Spec:** String URL, object `{type:, url:}`, or shorthand (`github:user/repo`, `user/repo`, `gitlab:user/repo`, `bitbucket:user/repo`).
**Extraction:** Add a private `normalize_repository_url(repo)` helper:
- If Hash, use `repo["url"]`
- If String, expand shorthands: `github:u/r` → `https://github.com/u/r`, bare `u/r` → `https://github.com/u/r`, `gitlab:u/r` → `https://gitlab.com/u/r`, `bitbucket:u/r` → `https://bitbucket.org/u/r`
- Run through `URLNormalizer.normalize` (strips `.git`, converts `git://`)
**Fixture:** Add `"repository": {"type": "git", "url": "https://github.com/librarian/librarian.git"}` to `spec/fixtures/package.json`
**Expected:** `repository_url: "https://github.com/librarian/librarian"`

### cargo — `lib/bibliothecary/parsers/cargo.rb`, `parse_manifest` (line 26)

**Field:** `manifest.dig("package", "repository")`
**Fixture:** Add `repository = "https://github.com/example/update"` under `[package]` in `spec/fixtures/Cargo.toml`
**Expected:** `repository_url: "https://github.com/example/update"`

### pub — `lib/bibliothecary/parsers/pub.rb`, `parse_yaml_manifest` (line 28)

**Field:** `manifest["repository"]`. Fallback: `manifest["homepage"]` if it's a forge URL.
**Fixture:** Add `repository: https://github.com/angulardart/angular` to `spec/fixtures/pubspec.yaml`
**Expected:** `repository_url: "https://github.com/angulardart/angular"`

### elm — `lib/bibliothecary/parsers/elm.rb`, `parse_json_runtime_manifest` (line 27)

**Field:** `manifest["repository"]`
**Fixture:** Already has `"repository": "https://github.com/elm-lang/package.elm-lang.org.git"` in `spec/fixtures/elm-package.json`
**Expected:** `repository_url: "https://github.com/elm-lang/package.elm-lang.org"` (`.git` stripped)

### haxelib — `lib/bibliothecary/parsers/haxelib.rb`, `parse_manifest` (line 24)

**Field:** `manifest["url"]` — only if it's a forge URL (haxelib `url` is often a project homepage, not a repo)
**Fixture:** Already has `"url": "http://haxeflixel.com"` in `spec/fixtures/haxelib.json` — not a forge URL, so `nil`
**Expected:** `repository_url: nil`

### deno — `lib/bibliothecary/parsers/deno.rb`, `parse_manifest` (line 31)

**Field:** `manifest["repository"]` (deno.json supports this for JSR publishing)
**Fixture:** Check if fixture has it; add if missing
**Expected:** `repository_url:` value or `nil`

---

## Batch 2: Nested/Structured Fields (5 parsers)

### cpan — `lib/bibliothecary/parsers/cpan.rb`

**META.json** (`parse_json_manifest`, line 45): `manifest.dig("resources", "repository", "url")` or fallback to `manifest.dig("resources", "repository")` if it's a plain string. Fallback: `manifest.dig("resources", "homepage")` if forge URL.
**Fixture:** Already has `"resources": {"repository": {"type": "git", "url": "git://github.com/creaktive/rainbarf.git"}}` in `spec/fixtures/META.json`
**Expected:** `repository_url: "https://github.com/creaktive/rainbarf"` (normalized: `git://` → `https://`, `.git` stripped)

**META.yml** (`parse_yaml_manifest`, line 53): Same path. Check if `resources.repository` is a Hash (use `["url"]` or `["web"]`) or a String.
**Fixture:** `spec/fixtures/META.yml` has `resources:` with only `license:`, no `repository`.
**Expected:** `repository_url: nil`

### pypi — `lib/bibliothecary/parsers/pypi.rb`

**pyproject.toml** (`parse_pyproject`, line 184): Check `[project.urls]` for keys (case-insensitive) in priority order: "Repository", "Source Code", "Source", "GitHub". Fallback: `dig("tool", "poetry", "repository")`. Final fallback: "Homepage" key if forge URL.
**Fixture:** `spec/fixtures/pyproject.toml` is poetry-style, no `[project.urls]`. Add `repository = "https://github.com/tidelift/tidelift"` under `[tool.poetry]`.
**Expected:** `repository_url: "https://github.com/tidelift/tidelift"`

**setup.py** (`parse_setup_py`, line 345): Extract `url=` kwarg via regex: `/url\s*=\s*['"]([^'"]+)['"]/`
**Fixture:** Already has `url='http://github.com/political-memory/political_memory/'` in `spec/fixtures/setup.py`
**Expected:** `repository_url: "http://github.com/political-memory/political_memory/"`

### packagist — `lib/bibliothecary/parsers/packagist.rb`, `parse_manifest` (line 65)

**Field:** `manifest.dig("support", "source")`. Fallback: `manifest["homepage"]` if forge URL.
**Fixture:** `spec/fixtures/composer.json` does not have `support.source`. Add `"support": {"source": "https://github.com/laravel/laravel"}` to fixture.
**Expected:** `repository_url: "https://github.com/laravel/laravel"`

### rubygems — `lib/bibliothecary/parsers/rubygems.rb`, `parse_gemspec` (line 149)

**Field:** Regex for `metadata["source_code_uri"]`: `/\.metadata\s*\[?\s*['"]source_code_uri['"]\s*\]?\s*=\s*['"]([^'"]+)['"]/`. Fallback: `homepage` regex `/\.homepage\s*=\s*['"]([^'"]+)['"]/` if it's a forge URL.
**Fixture:** Check gemspec fixtures. `spec/fixtures/example.podspec` is wrong type — find actual gemspec fixture (likely `devise.gemspec` or similar).
**Expected:** `repository_url:` extracted URL

---

## Batch 3: XML Manifests (2 parsers)

### maven — `lib/bibliothecary/parsers/maven.rb`, `parse_standalone_pom_manifest` (line 512)

**Field:** `project.locate("scm/url").first&.nodes&.first&.to_s&.strip`
**Fixture:** `spec/fixtures/pom.xml` — add `<scm><url>https://github.com/accidia/echo</url></scm>` if not present
**Expected:** `repository_url: "https://github.com/accidia/echo"`

### nuget — `lib/bibliothecary/parsers/nuget.rb`

**csproj** (`parse_csproj`, line 125): `property_group.locate("RepositoryUrl").first&.nodes&.first&.to_s&.strip`
**nuspec** (`parse_nuspec`, line 205): `manifest.package.metadata.locate("repository").first&.attributes&.[](:url)`. Fallback: `projectUrl` node if forge URL.
**Fixture updates:** Add `<RepositoryUrl>` to csproj fixture if not present.

---

## Batch 4: Regex/DSL Extraction (4 parsers)

### cocoapods — `lib/bibliothecary/parsers/cocoapods.rb`

**podspec** (`parse_podspec`, line 98): Regex for `s.source = { git: "url" }` or `s.source = { :git => "url" }`:
```ruby
/\.source\s*=\s*\{[^}]*(?::git\s*=>|git:)\s*['"]([^'"]+)['"]/
```
Fallback: `homepage` regex if forge URL.
**Fixture:** `spec/fixtures/example.podspec` has `s.source = { git: "https://github.com/CocoaLumberjack/CocoaLumberjack.git" }`
**Expected:** `repository_url: "https://github.com/CocoaLumberjack/CocoaLumberjack"` (`.git` stripped)

**podspec.json** (`parse_json_manifest`, line 184): `manifest.dig("source", "git")`. Fallback: `manifest["homepage"]` if forge URL.
**Fixture:** `spec/fixtures/example.podspec.json` has `"source": {"git": "https://github.com/AddAloner/ALOSRPAuth.git"}`
**Expected:** `repository_url: "https://github.com/AddAloner/ALOSRPAuth"` (`.git` stripped)

### hackage — `lib/bibliothecary/parsers/hackage.rb`, `parse_cabal` (line 44)

**Field:** `homepage:` line (standard cabal field):
```ruby
file_contents.lines.find { |l| l.match?(/^homepage:/i) }&.match(/^homepage:\s*(.+)$/i)&.captures&.first&.strip
```
**Fixture:** `spec/fixtures/example.cabal` has `homepage: https://github.com/alunduil/librariesio-cabal-parser`
**Expected:** `repository_url: "https://github.com/alunduil/librariesio-cabal-parser"`

### cran — `lib/bibliothecary/parsers/cran.rb`, `parse_description` (line 30)

**Field:** `fields["URL"]` — comma-separated list. Pick the first forge URL; fall back to first URL.
```ruby
def self.extract_repository_url(fields)
  url_field = fields["URL"]
  return nil unless url_field
  urls = url_field.split(/,\s*/).map(&:strip).reject(&:empty?)
  urls.find { |u| URLNormalizer.forge_url?(u) } || urls.first
end
```
**Fixture:** `spec/fixtures/DESCRIPTION` has `URL: http://ggplot2.org, https://github.com/hadley/ggplot2`
**Expected:** `repository_url: "https://github.com/hadley/ggplot2"`

### clojars — `lib/bibliothecary/parsers/clojars.rb`, `parse_manifest` (line 25)

**Field:** `:url` in defproject: `file_contents.match(/:url\s+"([^"]+)"/)&.captures&.first`
**Fixture:** `spec/fixtures/project.clj` has `:url "http://example.com/FIXME"`
**Expected:** `repository_url: "http://example.com/FIXME"`

---

## Parsers Excluded (no repository URL in manifest format)

go, docker, alpm, apk, deb, rpm, homebrew, actions, ollama, bentoml, cog, mlflow, dvc, nix, conda, carthage, meteor, julia, vcpkg, nimble, bazel, conan, shard, bower — these either have no project-level repository URL field, are lockfile-only, or are system/container/ML manifests.

---

## Key Files to Modify

| File | Change |
|------|--------|
| `lib/bibliothecary/parser_result.rb` | Add `repository_url` to FIELDS, initialize |
| `lib/bibliothecary/analyser.rb` | Add `repository_url` to `create_analysis` |
| `lib/bibliothecary/url_normalizer.rb` | **New file** — shared URL normalization |
| `lib/bibliothecary/parsers/npm.rb` | Extract + normalize `repository` field, or forge `homepage` |
| `lib/bibliothecary/parsers/cargo.rb` | Extract `package.repository` or forge `package.homepage` |
| `lib/bibliothecary/parsers/pub.rb` | Extract `repository` or forge `homepage` |
| `lib/bibliothecary/parsers/elm.rb` | Extract `repository` |
| `lib/bibliothecary/parsers/haxelib.rb` | Extract `url` if forge URL |
| `lib/bibliothecary/parsers/deno.rb` | Extract `repository` |
| `lib/bibliothecary/parsers/cpan.rb` | Extract `resources.repository.url` |
| `lib/bibliothecary/parsers/pypi.rb` | Extract from `project.urls` / `tool.poetry.repository` / `url=` |
| `lib/bibliothecary/parsers/packagist.rb` | Extract `support.source` or forge `homepage` |
| `lib/bibliothecary/parsers/rubygems.rb` | Extract `source_code_uri` or forge `homepage` |
| `lib/bibliothecary/parsers/maven.rb` | Extract `scm/url` from XML |
| `lib/bibliothecary/parsers/nuget.rb` | Extract `RepositoryUrl` from csproj/nuspec |
| `lib/bibliothecary/parsers/cocoapods.rb` | Extract `source.git` from podspec/podspec.json |
| `lib/bibliothecary/parsers/hackage.rb` | Extract `homepage:` line |
| `lib/bibliothecary/parsers/cran.rb` | Extract forge URL from `URL:` field |
| `lib/bibliothecary/parsers/clojars.rb` | Extract `:url` from defproject |

---

## Verification

1. `bundle exec rspec` — all existing tests pass after Step 0
2. After each batch, run targeted specs: `bundle exec rspec spec/parsers/<parser>_spec.rb`
3. Final full suite: `bundle exec rspec` — all pass with new `repository_url` assertions
