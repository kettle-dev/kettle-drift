# frozen_string_literal: true

require "json"
require "fileutils"
require "set"

module Kettle
  module Drift
    # Scans managed files for repeated adjacent-line chunks that usually signal
    # duplication drift or template corruption.
    module DuplicateLineValidator
      module_function

      DEFAULT_MIN_CHARS = 6
      BINARY_EXTENSIONS = Set.new(%w[
        .7z
        .bz2
        .class
        .dll
        .exe
        .gem
        .gif
        .gz
        .ico
        .jar
        .jpeg
        .jpg
        .pdf
        .png
        .so
        .tar
        .tgz
        .ttf
        .woff
        .woff2
        .xz
        .zip
      ]).freeze
      APPRAISALS_DEP_LINE_RE = /\A(?:eval_gemfile|gem)\s+["']/
      CHANGELOG_METRIC_RE = /\A-\s+(?:(?:(?:line|branch)\s+)?coverage:|\d+\.\d+%\s+documented)/i
      EXCLUDED_FILENAMES = Set.new(["CODE_OF_CONDUCT.md", ".gitlab-ci.yml"]).freeze
      KETTLE_JEM_CONFIG_RE = /\A(?:strategy|recipe|preference|add_missing|freeze_token|file_type|max_recursion_depth):\s/
      RAKEFILE_ENV_ASSIGNMENT_RE = /\AENV\[["']/
      RESCUE_LOAD_ERROR_RE = /\Arescue\s+LoadError/
      NOCOV_MARKER_RE = /\A# :nocov:\z/
      CHANGELOG_SUBHEADINGS = Set.new([
        "### Added",
        "### Changed",
        "### Deprecated",
        "### Removed",
        "### Fixed",
        "### Security",
      ]).freeze

      def scan(files:, min_chars: DEFAULT_MIN_CHARS)
        duplicates = {}

        files.each do |path|
          next unless File.file?(path)
          next if EXCLUDED_FILENAMES.include?(File.basename(path.to_s))

          content = read_text_content(path)
          next unless content

          fence_lines = (File.extname(path.to_s) == ".md") ? compute_fence_lines(content) : Set.new
          indexed = content.each_line.map.with_index(1) { |raw, n| [n, raw.strip] }

          chunk_map = Hash.new { |h, k| h[k] = [] }
          indexed.each_cons(2) do |(lineno1, line1), (lineno2, line2)|
            next if line1.gsub(/\s/, "").length <= min_chars
            next if line2.gsub(/\s/, "").length <= min_chars
            next if CHANGELOG_SUBHEADINGS.include?(line1)
            next if fence_lines.include?(lineno1) && fence_lines.include?(lineno2)
            next if ignored_duplicate_chunk?(path, line1, line2)

            chunk_map["#{line1}\n#{line2}"] << lineno1
          end

          chunk_map.each do |chunk_content, start_lines|
            next if start_lines.size < 2

            duplicates[chunk_content] ||= []
            duplicates[chunk_content] << {
              file: path,
              lines: start_lines,
            }
          end
        end

        duplicates
      end

      def ignored_duplicate_chunk?(path, line1, line2)
        basename = File.basename(path.to_s)

        if basename == "Appraisals"
          return true if APPRAISALS_DEP_LINE_RE.match?(line1) && APPRAISALS_DEP_LINE_RE.match?(line2)
          return true if line1.start_with?("#") && APPRAISALS_DEP_LINE_RE.match?(line2)
        end

        return true if basename == "CHANGELOG.md" && CHANGELOG_METRIC_RE.match?(line1) && CHANGELOG_METRIC_RE.match?(line2)
        return true if basename == "Rakefile" && RAKEFILE_ENV_ASSIGNMENT_RE.match?(line1) && RAKEFILE_ENV_ASSIGNMENT_RE.match?(line2)
        return true if RESCUE_LOAD_ERROR_RE.match?(line1) && NOCOV_MARKER_RE.match?(line2)
        return true if File.extname(path.to_s) == ".md" && line1.start_with?("|") && line2.start_with?("|")
        return true if basename == ".kettle-jem.yml" && KETTLE_JEM_CONFIG_RE.match?(line1) && KETTLE_JEM_CONFIG_RE.match?(line2)

        false
      end

      def compute_fence_lines(content)
        in_fence = false
        fence_marker = nil
        fence_lines = Set.new

        content.each_line.with_index(1) do |raw, lineno|
          stripped = raw.strip
          if in_fence
            fence_lines.add(lineno)
            if stripped.match?(/\A#{Regexp.escape(fence_marker)}\s*\z/)
              in_fence = false
              fence_marker = nil
            end
          elsif (match = stripped.match(/\A(`{3,}|~{3,})/))
            fence_marker = match[1]
            in_fence = true
            fence_lines.add(lineno)
          end
        end

        fence_lines
      end

      def scan_template_results(template_results:, min_chars: DEFAULT_MIN_CHARS)
        written_files = template_results.select { |_path, rec| %i[create replace].include?(rec[:action]) }.keys
        scan(files: written_files, min_chars: min_chars)
      end

      def baseline(template_dir: nil, min_chars: DEFAULT_MIN_CHARS)
        return Set.new unless template_dir && File.directory?(template_dir)

        template_files = Dir.glob(
          File.join(template_dir, "**", "*"),
          File::FNM_DOTMATCH,
        ).select { |f| File.file?(f) }

        Set.new(scan(files: template_files, min_chars: min_chars).keys)
      end

      def subtract_baseline(results, baseline_set:)
        results.reject { |line_content, _| baseline_set.include?(line_content) }
      end

      def template_managed_files(project_root:, template_dir: nil)
        template_dir ||= File.join(project_root, "template")
        return [] unless File.directory?(template_dir)

        managed = []
        Dir.glob(File.join(template_dir, "**", "*"), File::FNM_DOTMATCH).each do |src|
          next unless File.file?(src)

          rel = src.sub(%r{^#{Regexp.escape(template_dir)}/?}, "")
          rel = rel.sub(/\.example\z/, "")
          next if rel.include?(".no-osc")

          dest = File.join(project_root, rel)
          managed << dest if File.file?(dest)
        end

        managed.uniq
      end

      def warning_count(results)
        results.values.flatten.size
      end

      def to_json(results)
        JSON.pretty_generate(results.transform_values do |entries|
          entries.map { |entry| {file: Kettle::Drift.display_path(entry[:file]), lines: entry[:lines]} }
        end)
      end

      def write_json(results, json_path)
        FileUtils.mkdir_p(File.dirname(json_path))
        File.write(json_path, to_json(results))
        json_path
      end

      def report_summary(results, project_root: nil)
        return "No duplicate lines detected.\n" if results.empty?

        lines = ["### Duplicate Line Report\n", "| Chunk (line1 ↵ line2) | File | Start Lines |", "|---|---|---|"]

        results.each do |content, entries|
          display = content.gsub("\n", " ↵ ")
          display = "#{display[0, 77]}..." if display.length > 80
          display = display.gsub("|", "\\|")

          entries.each do |entry|
            file = Kettle::Drift.display_path(entry[:file])
            if project_root
              display_root = Kettle::Drift.display_path(project_root)
              file = file.sub(%r{^#{Regexp.escape(display_root)}/?}, "")
            end
            lines << "| `#{display}` | #{file} | #{entry[:lines].join(", ")} |"
          end
        end

        lines << ""
        lines.join("\n")
      end

      def read_text_content(path)
        raw = File.binread(path)
        return if binary_content?(path, raw)

        content = raw.dup.force_encoding(Encoding::UTF_8)
        return content if content.valid_encoding?

        content.scrub
      rescue StandardError
        nil
      end

      def binary_content?(path, raw)
        return true if BINARY_EXTENSIONS.include?(File.extname(path.to_s).downcase)

        sample = raw.byteslice(0, 4096) || "".b
        return true if sample.include?("\x00")
        return false if sample.empty?

        control_bytes = sample.each_byte.count do |byte|
          (0..8).cover?(byte) || byte == 11 || byte == 12 || (14..31).cover?(byte)
        end
        control_bytes.fdiv(sample.bytesize) > 0.1
      end
    end
  end
end
