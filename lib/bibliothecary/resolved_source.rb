# frozen_string_literal: true

module Bibliothecary
  # ResolvedSource describes where a dependency was resolved from: a git repository,
  # a local path, or a registry.
  class ResolvedSource
    attr_reader :type,
                :url, :host, :namespace, :project, :committish,
                :path, :workspace, :link,
                :registry_url, :tarball_url

    def self.git(url:, host: nil, namespace: nil, project: nil, committish: nil)
      new(type: :git, url: url, host: host, namespace: namespace, project: project, committish: committish)
    end

    def self.local(path:, workspace: false, link: false)
      new(type: :local, path: path, workspace: workspace, link: link)
    end

    def self.registry(registry_url:, tarball_url: nil)
      new(type: :registry, registry_url: registry_url, tarball_url: tarball_url)
    end

    def self.from_h(hash)
      return nil if hash.nil?
      return hash if hash.is_a?(ResolvedSource)

      case hash[:type]
      when :git
        git(url: hash[:url], host: hash[:host], namespace: hash[:namespace],
            project: hash[:project], committish: hash[:committish])
      when :local
        local(path: hash[:path], workspace: hash.fetch(:workspace, false),
              link: hash.fetch(:link, false))
      when :registry
        registry(registry_url: hash[:registry_url], tarball_url: hash[:tarball_url])
      end
    end

    def to_h
      case type
      when :git
        h = { type: :git, url: url }
        h[:host] = host unless host.nil?
        h[:namespace] = namespace unless namespace.nil?
        h[:project] = project unless project.nil?
        h[:committish] = committish unless committish.nil?
        h
      when :local
        { type: :local, path: path, workspace: workspace, link: link }
      when :registry
        { type: :registry, registry_url: registry_url, tarball_url: tarball_url }
      end
    end

    def ==(other)
      return false if other.nil?
      return to_h == other.to_h if other.is_a?(ResolvedSource)

      false
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    private

    def initialize(type:, url: nil, host: nil, namespace: nil, project: nil, committish: nil,
                   path: nil, workspace: nil, link: nil, registry_url: nil, tarball_url: nil)
      @type = type
      @url = url
      @host = host
      @namespace = namespace
      @project = project
      @committish = committish
      @path = path
      @workspace = workspace
      @link = link
      @registry_url = registry_url
      @tarball_url = tarball_url
    end
  end
end
