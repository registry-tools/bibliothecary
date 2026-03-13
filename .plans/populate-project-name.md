# Plan: Populate `project_name` in All Applicable Parsers

## Context

`ParserResult` already has a `project_name` field (defaults to `nil`) but no parser populates it. This field should hold the name under which the project could be published to its ecosystem's module registry (e.g., the `"name"` field in `package.json`, the `[package] name` in `Cargo.toml`, etc.). It is intentionally optional — many ecosystems (Docker, system packages, GitHub Actions) don't have a meaningful publishable project name.

**Goal:** For every parser that handles a manifest format containing a project/package name, extract and return it as `project_name` in `ParserResult`. Use TDD — failing test first, then implementation.

---

## Key Files

- `lib/bibliothecary/parser_result.rb` — `ParserResult` class with `project_name` field (already defined, just never populated)
- `lib/bibliothecary/parsers/` — 44 parser files
- `spec/parsers/` — one spec file per parser
- `spec/fixtures/` — fixture files referenced by tests
- `spec/spec_helper.rb` — `load_fixture(name)` and `fixture_path(name)` test helpers

## `analyse_contents` vs `parse_*` methods

Parsers define `parse_XYZ(file_contents, options: {})` class methods that return `ParserResult.new(...)`. The `analyse_contents` integration method wraps these and returns a hash with `project_name:` included. So changes are only needed in the individual `parse_*` methods — no changes to `analyser.rb` or `parser_result.rb`.

---

## Workflow Per Batch (TDD)

For each batch, a **coder agent** will:
1. Write failing test(s) asserting the expected `project_name` value in each affected spec file
2. Run `bundle exec rspec spec/parsers/PARSER_spec.rb` — confirm failure
3. Implement `project_name` extraction in the relevant `parse_*` method(s)
4. Run `bundle exec rspec spec/parsers/PARSER_spec.rb` — confirm pass
5. Run `bundle exec rspec` — confirm no regressions

Then **I (coordinator)** validate the diff and commit.

### TDD Test Pattern

Add a test within the existing spec for the manifest parse method. The assertion pattern (following existing specs) is either:
```ruby
expect(described_class.analyse_contents(filename, fixture)).to include(
  project_name: "expected-name"
)
```
or update an existing `eq` assertion that currently has `project_name: nil` to use the real name.

---

## Parsers to Modify (Grouped by Batch)

### Batch 1 — Simple JSON/YAML `name` field

All these manifest formats have a top-level `"name"` key.

| Parser | File | Method | Extraction |
|--------|------|---------|------------|
| npm | `npm.rb` | `parse_manifest` | `manifest["name"]` from `package.json` |
| bower | `bower.rb` | `parse` | `manifest["name"]` from `bower.json` |
| deno | `deno.rb` | `parse_manifest` | `manifest["name"]` from `deno.json` |
| dub | `dub.rb` | `parse_dub_json` | `manifest["name"]` from `dub.json` |
| haxelib | `haxelib.rb` | `parse` | `manifest["name"]` from `haxelib.json` |
| pub | `pub.rb` | `parse_manifest` | `manifest["name"]` from `pubspec.yaml` |
| shard | `shard.rb` | `parse_manifest` | `manifest["name"]` from `shard.yml` |
| vcpkg | `vcpkg.rb` | `parse_vcpkg_json` | `manifest["name"]` from `vcpkg.json` |

Fixtures to check: `spec/fixtures/package.json` (name: `"librarian"`), `spec/fixtures/bower.json`, `spec/fixtures/deno.json`, `spec/fixtures/dub.json`, `spec/fixtures/haxelib.json`, `spec/fixtures/pubspec.yaml`, `spec/fixtures/shard.yml`, `spec/fixtures/vcpkg.json`

### Batch 2 — TOML manifests

| Parser | File | Method | Extraction |
|--------|------|---------|------------|
| cargo | `cargo.rb` | `parse_manifest` | `parsed.dig("package", "name")` from `Cargo.toml` |
| julia | `julia.rb` | `parse_manifest_toml` | `parsed["name"]` from `Project.toml` |
| gleam (in hex) | `hex.rb` | `parse_gleam_toml` | `parsed["name"]` from `gleam.toml` |

Fixtures: `spec/fixtures/Cargo.toml` (name: `"update"`), `spec/fixtures/julia/Project.toml`, `spec/fixtures/gleam.toml`

### Batch 3 — Python ecosystem

PyPI has multiple manifest formats with different field locations.

| Parser | File | Method | Extraction |
|--------|------|---------|------------|
| pypi | `pypi.rb` | `parse_pyproject` | `parsed.dig("project","name")` (PEP 621) or `parsed.dig("tool","poetry","name")` |
| pypi | `pypi.rb` | `parse_setup_py` | regex: `/name\s*=\s*['"]([^'"]+)['"]/` |
| pypi | `pypi.rb` | `parse_setup_cfg` | `[metadata] name` line |

Lockfiles (Pipfile.lock, poetry.lock, requirements.txt) do NOT get `project_name`.

Fixtures: `spec/fixtures/pyproject.toml`, `spec/fixtures/setup.py`, `spec/fixtures/setup2.py`

### Batch 4 — XML/PHP

| Parser | File | Method | Extraction |
|--------|------|---------|------------|
| maven | `maven.rb` | `parse_pom_manifest` | `<artifactId>` (already extracted in tree parsers; adapt for pom) |
| nuget | `nuget.rb` | `parse_csproj` | `<PackageId>` or fallback `<AssemblyName>` |
| packagist | `packagist.rb` | `parse_manifest` | `manifest["name"]` from `composer.json` |

**Note:** Maven's `parse_maven_tree` already sets `project_name` — the pattern is established. For `pom.xml`, extract `<artifactId>` (and optionally prepend `<groupId>:` for full Maven coordinates).

Fixtures: `spec/fixtures/pom.xml`, `spec/fixtures/example.csproj`, `spec/fixtures/composer.json`

### Batch 5 — Ruby/DSL formats

These require regex extraction from DSL-style files.

| Parser | File | Method | Extraction |
|--------|------|---------|------------|
| rubygems | `rubygems.rb` | `parse_gemspec` | regex: `/spec\.name\s*=\s*['"]([^'"]+)['"]/` |
| hex | `hex.rb` | `parse_mix` | regex: `/app:\s*:(\w+)/` from `mix.exs` |
| cocoapods | `cocoapods.rb` | `parse_podspec` | regex: `/spec\.name\s*=\s*['"]([^'"]+)['"]/` |
| swift_pm | `swift_pm.rb` | `parse_package_swift` | regex: `/Package\s*\(\s*name:\s*"([^"]+)"/` |
| clojars | `clojars.rb` | `parse` | regex: `/defproject\s+([^\s]+)/` from `project.clj` |

Fixtures: `spec/fixtures/devise.gemspec`, `spec/fixtures/mix.exs`, `spec/fixtures/example.podspec`, `spec/fixtures/Package.swift`, `spec/fixtures/project.clj`

### Batch 6 — Line-based/text formats

| Parser | File | Method | Extraction |
|--------|------|---------|------------|
| go | `go.rb` | `parse_go_mod` | first `module` directive line |
| cpan | `cpan.rb` | `parse_json_manifest`, `parse_yaml_manifest` | `manifest["name"]` |
| cran | `cran.rb` | `parse_description` | `Package:` field line |
| hackage | `hackage.rb` | `parse_cabal` | `name:` field line |
| bazel | `bazel.rb` | parse method for `MODULE.bazel` | `module(name = "...")` |
| nimble | `nimble.rb` | `parse` | derive from `options[:filename]` (strip path + `.nimble` extension) |
| luarocks | `luarocks.rb` | `parse` | regex: `/^package\s*=\s*['"]([^'"]+)['"]/` |

Fixtures: `spec/fixtures/go.mod`, `spec/fixtures/META.json`, `spec/fixtures/DESCRIPTION`, `spec/fixtures/example.cabal`, `spec/fixtures/MODULE.bazel`, `spec/fixtures/example.nimble`, `spec/fixtures/example.rockspec`

### Batch 7 — C/C++ and Elixir rebar/conan

| Parser | File | Method | Extraction |
|--------|------|---------|------------|
| conan | `conan.rb` | `parse_conanfile_py` | class attribute: regex `/^\s*name\s*=\s*['"]([^'"]+)['"]/` |

`conanfile.txt` has no project name (only `[requires]` section) — skip.

Fixtures: `spec/fixtures/conanfile.py`

---

## Parsers Explicitly Skipped (no publishable project name)

- `docker.rb` — Dockerfile/docker-compose, no registry name
- `alpm.rb`, `apk.rb`, `deb.rb`, `rpm.rb` — system package dependency declarations
- `homebrew.rb` — Brewfile lists formulas to install, not a publishable package
- `actions.rb` — GitHub Actions workflow files
- `ollama.rb` — Modelfile defines a model to run, not a package
- `bentoml.rb`, `cog.rb` — service definitions, not named packages
- `mlflow.rb`, `dvc.rb` — ML project files without registry names
- `nix.rb` — `flake.nix` structure too complex, no simple name
- `carthage.rb` — `Cartfile` only lists deps, doesn't define project name
- `conda.rb` — `environment.yml` `name:` is environment name, not publishable package
- `elm.rb` — uses `author/project` repo path format, not a simple name field

---

## Execution Order

Process batches **sequentially** (each batch committed before next starts):

1. Batch 1 (JSON/YAML simple) — 8 parsers, low risk
2. Batch 2 (TOML) — 3 parsers
3. Batch 3 (Python) — complex due to multiple formats
4. Batch 4 (XML/PHP) — maven requires care (already has partial support)
5. Batch 5 (DSL/regex) — 5 parsers
6. Batch 6 (line-based) — 7 parsers
7. Batch 7 (conan) — 1 parser

---

## Validation Criteria (per batch)

Before committing each batch:
- [ ] All new tests are green
- [ ] Full `bundle exec rspec` passes with no regressions
- [ ] Each `parse_*` method only sets `project_name` when the value is actually present (non-nil guard)
- [ ] Lockfile parse methods are NOT modified — only manifest parse methods
- [ ] Diff looks minimal and targeted (no unrelated changes)
