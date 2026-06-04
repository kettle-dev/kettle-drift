# frozen_string_literal: true

require "json"

module Kettle
  module Drift
    module Serializer
      class << self
        def normalize(results, project_root: nil)
          deserialize(serialize(results, project_root: project_root))
        end

        def serialize(results, project_root: nil)
          "#{JSON.pretty_generate(normalize_results(results, project_root: project_root))}\n"
        end

        def deserialize(data)
          parsed = JSON.parse(data)
          raise Kettle::Drift::Error, "Wrong format of the lock file: expected a JSON object" unless parsed.is_a?(Hash)

          parsed.keys.sort.each_with_object({}) do |chunk, normalized|
            entries = parsed.fetch(chunk)
            unless entries.is_a?(Array)
              raise Kettle::Drift::Error, "Wrong format of the lock file: `#{chunk}` must map to an array"
            end

            normalized[chunk] = entries.map { |entry| deserialize_entry(chunk, entry) }
          end
        rescue JSON::ParserError => e
          raise Kettle::Drift::Error, "Wrong format of the lock file: #{e.message}"
        end

        private

        def normalize_results(results, project_root:)
          raise Kettle::Drift::Error, "Cannot serialize duplicate results: expected a Hash" unless results.is_a?(Hash)

          results.keys.sort.each_with_object({}) do |chunk, normalized|
            entries = Array(results.fetch(chunk)).map { |entry| normalize_entry(entry, project_root: project_root) }
            normalized[chunk.to_s] = entries.sort_by { |entry| [entry.fetch("file"), entry.fetch("lines")] }
          end
        end

        def normalize_entry(entry, project_root:)
          file = entry[:file] || entry["file"]
          lines = entry[:lines] || entry["lines"]

          raise Kettle::Drift::Error, "Cannot serialize duplicate results: missing file path" if file.to_s.strip.empty?
          raise Kettle::Drift::Error, "Cannot serialize duplicate results: lines must be an array" unless lines.is_a?(Array)

          {
            "file" => relative_path(file, project_root: project_root),
            "lines" => lines.map { |line| Integer(line) }
          }
        end

        def deserialize_entry(chunk, entry)
          unless entry.is_a?(Hash)
            raise Kettle::Drift::Error, "Wrong format of the lock file: `#{chunk}` entries must be objects"
          end

          file = entry["file"]
          lines = entry["lines"]
          raise Kettle::Drift::Error, "Wrong format of the lock file: `#{chunk}` entries must include file" if file.to_s.strip.empty?
          raise Kettle::Drift::Error, "Wrong format of the lock file: `#{chunk}` entries must include a lines array" unless lines.is_a?(Array)

          {
            file: file,
            lines: lines.map { |line| Integer(line) }
          }
        end

        def relative_path(path, project_root:)
          file = path.to_s
          return file if project_root.to_s.strip.empty?

          root = File.expand_path(project_root.to_s)
          absolute_file = File.expand_path(file)
          return file unless absolute_file == root || absolute_file.start_with?("#{root}/")

          absolute_file.delete_prefix("#{root}/").delete_prefix(root)
        end
      end
    end
  end
end
