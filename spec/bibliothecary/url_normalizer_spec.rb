# frozen_string_literal: true

require "spec_helper"

describe Bibliothecary::URLNormalizer do
  describe ".normalize" do
    it "returns nil for nil input" do
      expect(described_class.normalize(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.normalize("")).to be_nil
    end

    it "returns nil for whitespace-only string" do
      expect(described_class.normalize("   ")).to be_nil
    end

    it "strips leading and trailing whitespace" do
      expect(described_class.normalize("  https://github.com/foo/bar  ")).to eq("https://github.com/foo/bar")
    end

    it "converts git:// protocol to https://" do
      expect(described_class.normalize("git://github.com/foo/bar")).to eq("https://github.com/foo/bar")
    end

    it "removes .git suffix" do
      expect(described_class.normalize("https://github.com/foo/bar.git")).to eq("https://github.com/foo/bar")
    end

    it "handles git:// protocol and .git suffix together" do
      expect(described_class.normalize("git://github.com/foo/bar.git")).to eq("https://github.com/foo/bar")
    end

    it "leaves https URLs without .git unchanged" do
      expect(described_class.normalize("https://github.com/foo/bar")).to eq("https://github.com/foo/bar")
    end

    it "converts git+https:// protocol to https://" do
      expect(described_class.normalize("git+https://github.com/npm/cli.git")).to eq("https://github.com/npm/cli")
    end

    it "handles maven SCM URLs" do
      expect(described_class.normalize("scm:git:https://github.com/foo/bar.git")).to eq("https://github.com/foo/bar")
    end

    [
      ["git@github.com:foo/bar.git", "https://github.com/foo/bar"],
      ["ssh://git@github.com:foo/bar.git", "https://github.com/foo/bar"],
      ["ssh://git@private-gitlab.io:7999/org/repo.git", "https://private-gitlab.io:7999/org/repo"],
    ].each do |input, expected|
      it "parses #{input} ssh URL" do
        expect(described_class.normalize(input)).to eq(expected)
      end
    end

    [
      ["npm/example", "https://github.com/npm/example"],
      ["github:npm/example", "https://github.com/npm/example"],
      ["gist:11081aaa281", "https://gist.github.com/11081aaa281"],
      ["bitbucket:user/repo", "https://bitbucket.org/user/repo"],
      ["gitlab:user/repo", "https://gitlab.com/user/repo"]
    ].each do |input, expected|
      it "parses #{input} shorthand URL" do
        expect(described_class.normalize(input)).to eq(expected)
      end
    end
  end

  describe ".forge_url?" do
    it "returns false for nil" do
      expect(described_class.forge_url?(nil)).to be false
    end

    it "matches GitHub URLs" do
      expect(described_class.forge_url?("https://github.com/foo/bar")).to be true
    end

    it "matches GitLab URLs" do
      expect(described_class.forge_url?("https://gitlab.com/foo/bar")).to be true
    end

    it "matches Bitbucket URLs" do
      expect(described_class.forge_url?("https://bitbucket.org/foo/bar")).to be true
    end

    it "matches Codeberg URLs" do
      expect(described_class.forge_url?("https://codeberg.org/foo/bar")).to be true
    end

    it "matches Sourcehut URLs" do
      expect(described_class.forge_url?("https://sr.ht/~foo/bar")).to be true
    end

    it "returns false for non-forge URLs" do
      expect(described_class.forge_url?("https://example.com/foo/bar")).to be false
    end
  end
end
