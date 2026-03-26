# frozen_string_literal: true

module Bibliothecary
  # ParserResult bundles together a list of dependencies, the project name, and the repository URL.
  #
  # @attr_reader [Array<Dependency>] dependencies The list of Dependency objects
  # @attr_reader [String,nil] project_name The name of the project
  # @attr_reader [Hash,nil] git_info The hosted git information of the project's source repository, if available.
  class ParserResult
    FIELDS = %i[
      dependencies
      project_name
      git_info
    ].freeze

    attr_reader(*FIELDS)

    def initialize(
      dependencies:,
      project_name: nil,
      git_info: nil
    )
      @dependencies = dependencies
      @project_name = project_name
      @git_info = git_info
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
