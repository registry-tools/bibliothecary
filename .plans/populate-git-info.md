# Plan: Populate `git_info` in All Applicable Parsers

## Context

`ParserResult` has `dependencies` and `project_name` fields. We need a third optional field, `git_info`, to capture the project's source repository information from manifest files when one is available. This is ecosystem-specific — each manifest format has different conventions for storing repository information. Use TDD: failing test first, then implementation.

## Requirements

1. **Normalize all URLs** — expand shorthands to full HTTPS URLs, convert `git://` to `https://`, strip `.git` suffixes
2. **Fall back to homepage** when it looks like a repository URL (particularly GitHub URLs)
3. **Batch by tier** to allow parallel coder agents

---

## Step 0: Core Infrastructure

### 0a. `lib/bibliothecary/parser_result.rb`

Add `git_info` to `FIELDS`, `attr_reader`, and `initialize` (optional kwarg, default `nil`). The existing `eql?`, `to_h`, and `hash` methods iterate over `FIELDS` so they update automatically.

### 0b. `lib/bibliothecary/analyser.rb` (line 21–30)

Add `git_info: parser_result.git_info` to the `create_analysis` output hash.

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

Adding `git_info` to `create_analysis` will break every test that does an exact `eq({...})` match on `analyse_contents` results. Add `git_info: nil` to every such expectation across all `spec/parsers/*_spec.rb` files. Run `bundle exec rspec` to find and fix all failures before proceeding.

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
