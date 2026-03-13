# frozen_string_literal: true

module Bibliothecary
  # ParserResult bundles together a list of dependencies, the project name, and the repository URL.
  #
  # @attr_reader [Array<Dependency>] dependencies The list of Dependency objects
  # @attr_reader [String,nil] project_name The name of the project
  # @attr_reader [String,nil] repository_url The URL of the project's source repository
  class ParserResult
    FIELDS = %i[
      dependencies
      project_name
      repository_url
    ].freeze

    attr_reader(*FIELDS)

    def initialize(
      dependencies:,
      project_name: nil,
      repository_url: nil
    )
      @dependencies = dependencies
      @project_name = project_name
      @repository_url = repository_url
    end

    def eql?(other)
      FIELDS.all? { |f| public_send(f) == other.public_send(f) }
    end
    alias == eql?

    def to_h
      FIELDS.to_h { |f| [f, public_send(f)] }
    end

    def hash
      FIELDS.map { |f| public_send(f) }.hash
    end
  end
end
