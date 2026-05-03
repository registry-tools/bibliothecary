# frozen_string_literal: true

require "spec_helper"

describe Bibliothecary::Parsers::Cargo do
  it "has a platform name" do
    expect(described_class.platform_name).to eq("cargo")
  end

  it "parses dependencies from Cargo.toml" do
    expect(described_class.analyse_contents("Cargo.toml", load_fixture("Cargo.toml"))).to eq({
                                                                                               platform: "cargo",
                                                                                               path: "Cargo.toml",
                                                                                               project_name: "update",
                                                                                               dependencies: [
        Bibliothecary::Dependency.new(platform: "cargo", name: "rustc-serialize", requirement: "*", type: "runtime", source: "Cargo.toml"),
        Bibliothecary::Dependency.new(platform: "cargo", name: "regex", requirement: "*", type: "runtime", source: "Cargo.toml"),
        Bibliothecary::Dependency.new(platform: "cargo", name: "regex-syntax", requirement: "https://github.com/rust-lang/regex.git", type: "runtime", source: "Cargo.toml", resolved_source: { type: :git, url: "https://github.com/rust-lang/regex#master", host: "github.com", namespace: "rust-lang", project: "regex", committish: "master" }),
        Bibliothecary::Dependency.new(platform: "cargo", name: "tempdir", requirement: "0.3", type: "development", source: "Cargo.toml"),
      ],
                                                                                               kind: "manifest",
                                                                                               success: true,
                                                                                               git_info: { host: "github.com", namespace: "example", project: "update" },
                                                                                             })
  end

  it "parses dependencies from Cargo.lock" do
    result = described_class.analyse_contents("Cargo.lock", load_fixture("Cargo.lock"))
    expect(result).to include({
                                platform: "cargo",
                                path: "Cargo.lock",
                                project_name: nil,
                                kind: "lockfile",
                                success: true,
                                git_info: nil,
                              })
    expect(result[:dependencies].length).to eq(16)
    # Spot check dependencies with integrity
    expect(result[:dependencies]).to include(
      Bibliothecary::Dependency.new(platform: "cargo", name: "aho-corasick", requirement: "0.7.18", type: "runtime", source: "Cargo.lock", integrity: "sha256=1e37cfd5e7657ada45f742d6e99ca5788580b5c529dc78faf11ece6dc702656f"),
      Bibliothecary::Dependency.new(platform: "cargo", name: "regex", requirement: "1.6.0", type: "runtime", source: "Cargo.lock", integrity: "sha256=4c4eb3267174b8c6c2f654116623910a0fef09c4753f8dd83db29c48a0df988b"),
      Bibliothecary::Dependency.new(platform: "cargo", name: "winapi", requirement: "0.3.9", type: "runtime", source: "Cargo.lock", integrity: "sha256=5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419")
    )
  end

  context "when Cargo.lock contains git dependencies" do

    it "parses dependencies from Cargo.lock" do
      result = described_class.analyse_contents("Cargo.lock", load_fixture("cargo-lock-with-git-repo/Cargo.lock"))
      expect(result).to include({
                                  platform: "cargo",
                                  path: "Cargo.lock",
                                  project_name: nil,
                                  kind: "lockfile",
                                  success: true,
                                  git_info: nil,
                                })
      expect(result[:dependencies].length).to eq(18)
      # Spot check dependencies with integrity/git info
      expect(result[:dependencies]).to include(
        Bibliothecary::Dependency.new(platform: "cargo", name: "remove_dir_all", requirement: "0.5.3", type: "runtime", source: "Cargo.lock", integrity: "sha256=3acd125665422973a33ac9d3dd2df85edad0f4ae9b00dafb1a05e43a9f5ef8e7"),
        Bibliothecary::Dependency.new(platform: "cargo", name: "regex-syntax", requirement: "0.8.10", type: "runtime", source: "Cargo.lock", integrity: nil, resolved_source: { type: :git, url: "https://github.com/rust-lang/regex.git?branch=master#839d16bc65b60e2006d3599d20bfa6efc14049d8", host: "github.com", namespace: "rust-lang", project: "regex", committish: "839d16bc65b60e2006d3599d20bfa6efc14049d8" }),
        Bibliothecary::Dependency.new(platform: "cargo", name: "winapi", requirement: "0.3.9", type: "runtime", source: "Cargo.lock", integrity: "sha256=5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419")
      )
    end
  end

  it "matches valid manifest filepaths" do
    expect(described_class.match?("Cargo.toml")).to be_truthy
    expect(described_class.match?("Cargo.lock")).to be_truthy
  end
end
