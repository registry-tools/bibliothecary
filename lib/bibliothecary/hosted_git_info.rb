require "uri"

module Bibliothecary
  class HostedGitInfo
    attr_reader :host, :namespace, :project

    attr_accessor :committish

    def valid?
      !host.nil? && !namespace.nil? && !project.nil?
    end

    def to_h
      return nil unless valid?
      {
        host: host,
        namespace: namespace,
        project: project,
      }.tap do |hash|
        hash[:committish] = committish unless committish.nil?
      end
    end

    def initialize(normalized_url)
      begin
        uri = URI.parse(normalized_url)
        @host = uri.hostname

        path = uri.path.sub(%r{^/}, "") # Remove leading slash
        path = path.sub(%r{\.git$}, "") # Remove trailing .git if present
        path_parts = path.split("/")

        if path_parts.length == 2
          @namespace = path_parts[0]
          @project = path_parts[1]
        end
        @committish = uri.fragment
      rescue
        # Invalid
      end
    end
  end
end
