# frozen_string_literal: true

require "version_gem"
require_relative "drift/version"

Kettle::Drift::Version.class_eval do
  extend VersionGem::Basic
end
module Kettle
  module Drift
    class Error < StandardError; end

    autoload :CLI, "kettle/drift/cli"
    autoload :DuplicateLineValidator, "kettle/drift/duplicate_line_validator"
    autoload :Diff, "kettle/drift/diff"
    autoload :LockFile, "kettle/drift/lock_file"
    autoload :Process, "kettle/drift/process"
    autoload :Serializer, "kettle/drift/serializer"

    class << self
      VAR_HOME_PREFIX = %r{\A/var/home(?=/|\z)}
      VAR_HOME_TEXT = %r{/var/home(?=/|\z)}

      def display_path(path)
        return path if path.nil?

        path.to_s.sub(VAR_HOME_PREFIX, "/home")
      end

      def display_text(text)
        return text if text.nil?

        text.to_s.gsub(VAR_HOME_TEXT, "/home")
      end
    end
  end
end
