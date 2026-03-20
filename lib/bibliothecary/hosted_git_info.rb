require "uri"

module Bibliothecary
  class HostedGitInfo
    attr_reader :host, :namespace, :project
    
    def valid?
      !host.nil? && !namespace.nil? && !project.nil
    end

    def initialize(normalized_url)
      begin
        uri = URI.parse(normalized_url)
        @host = uri.hostname
        path_parts = uri.path.split("/", 2)

        if path_parts == 2
          @namespace = path_parts[0]
          @project = path_parts[1]
        end
      rescue
        # Invalid
      end
    end
  end
end
