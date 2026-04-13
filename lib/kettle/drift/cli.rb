# frozen_string_literal: true

require "optparse"
require "set"

module Kettle
  module Drift
    class CLI
      def run(argv = ARGV)
        options = parse(argv)
        return options if options.is_a?(Integer)

        project_root = File.expand_path(options.fetch(:project_root))
        outcome = Kettle::Drift.run(
          project_root: project_root,
          template_dir: options[:template_dir],
          min_chars: options.fetch(:min_chars),
          json_path: options[:json_path],
          lock_path: options[:lock_path],
          mode: options.fetch(:mode),
        )

        if outcome.clean?
          puts "[kettle-drift] ✅  No duplicate drift detected (min_chars=#{options[:min_chars]}, files=#{outcome.files.size}, baseline=#{outcome.baseline_set.size})"
        else
          puts "[kettle-drift] ⚠️  #{outcome.warning_count} drift warning(s) across #{outcome.results.size} unique chunk(s) (files=#{outcome.files.size}, baseline=#{outcome.baseline_set.size})"
          puts "[kettle-drift] 📄  Report: #{Kettle::Drift.display_path(outcome.json_path)}" if outcome.json_path
        end

        outcome.exit_code
      end

      private

      def parse(argv)
        options = {
          min_chars: Kettle::Drift::DuplicateLineValidator::DEFAULT_MIN_CHARS,
          lock_path: Kettle::Drift::DEFAULT_LOCKFILE,
          mode: :update,
          project_root: Dir.pwd,
        }

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: kettle-drift [PROJECT_ROOT] [options]"
          opts.on("--min-chars=N", Integer, "Minimum non-whitespace characters per line") { |value| options[:min_chars] = value }
          opts.on("--json=PATH", "Write JSON report to PATH") { |value| options[:json_path] = value }
          opts.on("--lockfile=PATH", "Use PATH for the lockfile") { |value| options[:lock_path] = value }
          opts.on("--template-dir=PATH", "Use template-managed files and template baseline from PATH") { |value| options[:template_dir] = value }
          opts.on("--update", "Update the lockfile when drift is new, reduced, or otherwise changed (default)") { options[:mode] = :update }
          opts.on("--check", "Fail if current drift differs from the lockfile") { options[:mode] = :check }
          opts.on("--force-update", "Update the lockfile even when drift gets worse") { options[:mode] = :force_update }
        end

        remaining = parser.parse(argv.dup)
        options[:project_root] = remaining.first if remaining.first
        options[:template_dir] = expand_optional_path(options[:template_dir], File.expand_path(options[:project_root]))
        options[:lock_path] = File.expand_path(options.fetch(:lock_path), File.expand_path(options[:project_root]))
        options[:json_path] = options[:json_path] && File.expand_path(options[:json_path], File.expand_path(options[:project_root]))
        options
      rescue OptionParser::ParseError => e
        warn("[kettle-drift] #{e.message}")
        2
      end

      def expand_optional_path(path, project_root)
        return if path.to_s.strip.empty?

        File.expand_path(path, project_root)
      end
    end
  end
end
