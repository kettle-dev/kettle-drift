# frozen_string_literal: true

require "optparse"
require "set"

module Kettle
  module Drift
    class CLI
      DEFAULT_LOCKFILE = ".kettle-drift.lock"
      EXCLUDED_PATH_SEGMENTS = Set.new(%w[
        .bundle
        .git
        .idea
        coverage
        docs
        node_modules
        pkg
        tmp
        vendor
      ]).freeze

      def run(argv = ARGV)
        options = parse(argv)
        project_root = File.expand_path(options.fetch(:project_root))
        template_dir = expand_optional_path(options[:template_dir], project_root)
        lock_path = File.expand_path(options.fetch(:lock_path), project_root)
        json_path = options[:json_path] && File.expand_path(options[:json_path], project_root)

        files = target_files(project_root: project_root, template_dir: template_dir)
        baseline_set = template_dir ? Kettle::Drift::DuplicateLineValidator.baseline(template_dir: template_dir, min_chars: options.fetch(:min_chars)) : Set.new
        results = Kettle::Drift::DuplicateLineValidator.scan(files: files, min_chars: options.fetch(:min_chars))
        results = Kettle::Drift::DuplicateLineValidator.subtract_baseline(results, baseline_set: baseline_set)

        if results.empty?
          puts "[kettle-drift] ✅  No duplicate drift detected (min_chars=#{options[:min_chars]}, files=#{files.size}, baseline=#{baseline_set.size})"
        else
          puts "[kettle-drift] ⚠️  #{Kettle::Drift::DuplicateLineValidator.warning_count(results)} drift warning(s) across #{results.size} unique chunk(s) (files=#{files.size}, baseline=#{baseline_set.size})"
          json_path ||= File.join(project_root, "tmp", "kettle-drift", "duplicate-lines-#{Time.now.utc.strftime("%Y%m%d-%H%M%S")}.json")
          Kettle::Drift::DuplicateLineValidator.write_json(results, json_path)
          puts "[kettle-drift] 📄  Report: #{Kettle::Drift.display_path(json_path)}"
        end

        Kettle::Drift::Process.new(
          project_root: project_root,
          lock_path: lock_path,
          mode: options.fetch(:mode),
          results: results,
        ).call
      end

      private

      def parse(argv)
        options = {
          min_chars: Kettle::Drift::DuplicateLineValidator::DEFAULT_MIN_CHARS,
          lock_path: DEFAULT_LOCKFILE,
          mode: :update,
          project_root: Dir.pwd,
        }

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: kettle-drift [PROJECT_ROOT] [options]"
          opts.on("--min-chars=N", Integer, "Minimum non-whitespace characters per line") { |value| options[:min_chars] = value }
          opts.on("--json=PATH", "Write JSON report to PATH") { |value| options[:json_path] = value }
          opts.on("--lockfile=PATH", "Use PATH for the lockfile") { |value| options[:lock_path] = value }
          opts.on("--template-dir=PATH", "Use template-managed files and template baseline from PATH") { |value| options[:template_dir] = value }
          opts.on("--check", "Fail if current drift differs from the lockfile") { options[:mode] = :check }
          opts.on("--force-update", "Update the lockfile even when drift gets worse") { options[:mode] = :force_update }
        end

        remaining = parser.parse(argv.dup)
        options[:project_root] = remaining.first if remaining.first
        options
      rescue OptionParser::ParseError => e
        warn("[kettle-drift] #{e.message}")
        2
      end

      def expand_optional_path(path, project_root)
        return if path.to_s.strip.empty?

        File.expand_path(path, project_root)
      end

      def target_files(project_root:, template_dir:)
        return Kettle::Drift::DuplicateLineValidator.template_managed_files(project_root: project_root, template_dir: template_dir) if template_dir

        Dir.glob(File.join(project_root, "**", "*"), File::FNM_DOTMATCH).select do |path|
          next false unless File.file?(path)

          relative = path.delete_prefix("#{project_root}/")
          segments = relative.split("/")
          segments.none? { |segment| segment.start_with?(".") || EXCLUDED_PATH_SEGMENTS.include?(segment) }
        end
      end
    end
  end
end
