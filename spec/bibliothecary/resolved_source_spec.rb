# frozen_string_literal: true

require "spec_helper"

describe Bibliothecary::ResolvedSource do
  describe ".git" do
    it "builds a git resolved source with all fields" do
      rs = described_class.git(
        url: "https://github.com/vuejs/vue.git#v2.6.12",
        host: "github.com",
        namespace: "vuejs",
        project: "vue",
        committish: "v2.6.12"
      )

      expect(rs.type).to eq(:git)
      expect(rs.url).to eq("https://github.com/vuejs/vue.git#v2.6.12")
      expect(rs.host).to eq("github.com")
      expect(rs.namespace).to eq("vuejs")
      expect(rs.project).to eq("vue")
      expect(rs.committish).to eq("v2.6.12")
    end

    it "builds a git resolved source with only a URL" do
      rs = described_class.git(url: "https://github.com/vuejs/vue")
      expect(rs.type).to eq(:git)
      expect(rs.url).to eq("https://github.com/vuejs/vue")
      expect(rs.host).to be_nil
    end

    it "serializes to a hash, omitting nil optional fields" do
      rs = described_class.git(url: "https://github.com/vuejs/vue.git#v2.6.12", host: "github.com", namespace: "vuejs", project: "vue", committish: "v2.6.12")
      expect(rs.to_h).to eq({
        type: :git,
        url: "https://github.com/vuejs/vue.git#v2.6.12",
        host: "github.com",
        namespace: "vuejs",
        project: "vue",
        committish: "v2.6.12",
      })
    end

    it "omits committish from to_h when nil" do
      rs = described_class.git(url: "https://github.com/foo/bar", host: "github.com", namespace: "foo", project: "bar")
      expect(rs.to_h).to eq({ type: :git, url: "https://github.com/foo/bar", host: "github.com", namespace: "foo", project: "bar" })
      expect(rs.to_h).not_to have_key(:committish)
    end

    it "omits host/namespace/project from to_h when all nil" do
      rs = described_class.git(url: "https://example.com/something")
      expect(rs.to_h).to eq({ type: :git, url: "https://example.com/something" })
    end
  end

  describe ".local" do
    it "builds a local resolved source" do
      rs = described_class.local(path: "src/other-package", workspace: false, link: false)
      expect(rs.type).to eq(:local)
      expect(rs.path).to eq("src/other-package")
      expect(rs.workspace).to eq(false)
      expect(rs.link).to eq(false)
    end

    it "serializes to a hash" do
      rs = described_class.local(path: "src/other-package", workspace: false, link: false)
      expect(rs.to_h).to eq({ type: :local, path: "src/other-package", workspace: false, link: false })
    end

    it "defaults workspace and link to false" do
      rs = described_class.local(path: "../my-lib")
      expect(rs.workspace).to eq(false)
      expect(rs.link).to eq(false)
    end
  end

  describe ".registry" do
    it "builds a registry resolved source" do
      rs = described_class.registry(registry_url: "https://registry.npmjs.org", tarball_url: "https://registry.npmjs.org/foo/-/foo-1.0.0.tgz")
      expect(rs.type).to eq(:registry)
      expect(rs.registry_url).to eq("https://registry.npmjs.org")
      expect(rs.tarball_url).to eq("https://registry.npmjs.org/foo/-/foo-1.0.0.tgz")
    end

    it "serializes to a hash including nil tarball_url" do
      rs = described_class.registry(registry_url: "https://registry.npmjs.org", tarball_url: nil)
      expect(rs.to_h).to eq({ type: :registry, registry_url: "https://registry.npmjs.org", tarball_url: nil })
    end
  end

  describe ".from_h" do
    it "returns nil for nil input" do
      expect(described_class.from_h(nil)).to be_nil
    end

    it "returns the same ResolvedSource if already a ResolvedSource" do
      rs = described_class.registry(registry_url: "https://registry.npmjs.org", tarball_url: nil)
      expect(described_class.from_h(rs)).to be(rs)
    end

    it "coerces a git hash" do
      hash = { type: :git, url: "https://github.com/foo/bar", host: "github.com", namespace: "foo", project: "bar", committish: "v1.0" }
      rs = described_class.from_h(hash)
      expect(rs).to be_a(described_class)
      expect(rs.to_h).to eq(hash)
    end

    it "coerces a local hash" do
      hash = { type: :local, path: "src/pkg", workspace: true, link: false }
      rs = described_class.from_h(hash)
      expect(rs.to_h).to eq(hash)
    end

    it "coerces a registry hash" do
      hash = { type: :registry, registry_url: "https://registry.npmjs.org", tarball_url: nil }
      rs = described_class.from_h(hash)
      expect(rs.to_h).to eq(hash)
    end
  end

  describe "#==" do
    it "is equal to another ResolvedSource with the same attributes" do
      a = described_class.git(url: "https://github.com/foo/bar", host: "github.com", namespace: "foo", project: "bar")
      b = described_class.git(url: "https://github.com/foo/bar", host: "github.com", namespace: "foo", project: "bar")
      expect(a).to eq(b)
    end

    it "is not equal to a ResolvedSource with different attributes" do
      a = described_class.git(url: "https://github.com/foo/bar")
      b = described_class.git(url: "https://github.com/foo/baz")
      expect(a).not_to eq(b)
    end

    it "is not equal to nil" do
      rs = described_class.registry(registry_url: "https://registry.npmjs.org", tarball_url: nil)
      expect(rs).not_to eq(nil)
    end
  end

  describe "#hash" do
    it "is the same for equal objects" do
      a = described_class.local(path: "src/pkg", workspace: false, link: false)
      b = described_class.local(path: "src/pkg", workspace: false, link: false)
      expect(a.hash).to eq(b.hash)
    end

    it "can be used as a Hash key (deduplication)" do
      a = described_class.registry(registry_url: "https://registry.npmjs.org", tarball_url: nil)
      b = described_class.registry(registry_url: "https://registry.npmjs.org", tarball_url: nil)
      expect({ a => 1, b => 2 }.size).to eq(1)
    end
  end
end
