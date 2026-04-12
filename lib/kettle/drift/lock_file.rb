# frozen_string_literal: true

require "fileutils"

module Kettle
  module Drift
    class LockFile
      attr_reader :path

      def initialize(path)
        @path = path
      end

      def read_results
        return unless File.exist?(path)

        Kettle::Drift::Serializer.deserialize(File.read(path, encoding: Encoding::UTF_8))
      end

      def write_results(results, project_root: nil)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, Kettle::Drift::Serializer.serialize(results, project_root: project_root), encoding: Encoding::UTF_8)
      end

      def delete
        return unless File.exist?(path)

        File.delete(path)
      end
    end
  end
end
