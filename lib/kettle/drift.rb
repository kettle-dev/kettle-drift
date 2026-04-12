# frozen_string_literal: true

require "set"
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
    autoload :Outcome, "kettle/drift/outcome"
    autoload :Plugin, "kettle/drift/plugin"
    autoload :Process, "kettle/drift/process"
    autoload :Serializer, "kettle/drift/serializer"

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

      def install_tasks
        load("kettle/drift/tasks.rb")
      end

      def register_kettle_jem_plugin(registrar)
        Kettle::Drift::Plugin.register!(registrar)
      end

      def target_files(project_root:, template_dir: nil)
        return Kettle::Drift::DuplicateLineValidator.template_managed_files(project_root: project_root, template_dir: template_dir) if template_dir

        Dir.glob(File.join(project_root, "**", "*"), File::FNM_DOTMATCH).select do |path|
          next false unless File.file?(path)

          relative = path.delete_prefix("#{project_root}/")
          segments = relative.split("/")
          segments.none? { |segment| segment.start_with?(".") || EXCLUDED_PATH_SEGMENTS.include?(segment) }
        end
      end

      def run(
        project_root:,
        files: nil,
        template_dir: nil,
        min_chars: Kettle::Drift::DuplicateLineValidator::DEFAULT_MIN_CHARS,
        json_path: nil,
        lock_path: DEFAULT_LOCKFILE,
        mode: :update,
        printer_class: Kettle::Drift::Process::Printer
      )
        expanded_project_root = File.expand_path(project_root)
        expanded_template_dir = template_dir.to_s.strip.empty? ? nil : File.expand_path(template_dir, expanded_project_root)
        expanded_lock_path = File.expand_path(lock_path, expanded_project_root)
        selected_files = Array(files || target_files(project_root: expanded_project_root, template_dir: expanded_template_dir))
        baseline_set = expanded_template_dir ? Kettle::Drift::DuplicateLineValidator.baseline(template_dir: expanded_template_dir, min_chars: min_chars) : Set.new
        results = Kettle::Drift::DuplicateLineValidator.scan(files: selected_files, min_chars: min_chars)
        results = Kettle::Drift::DuplicateLineValidator.subtract_baseline(results, baseline_set: baseline_set)
        warning_count = Kettle::Drift::DuplicateLineValidator.warning_count(results)

        expanded_json_path = nil
        unless results.empty?
          expanded_json_path = if json_path
            File.expand_path(json_path, expanded_project_root)
          else
            File.join(expanded_project_root, "tmp", "kettle-drift", "duplicate-lines-#{Time.now.utc.strftime("%Y%m%d-%H%M%S")}.json")
          end
          Kettle::Drift::DuplicateLineValidator.write_json(results, expanded_json_path)
        end

        process_result = Kettle::Drift::Process.new(
          project_root: expanded_project_root,
          lock_path: expanded_lock_path,
          mode: mode,
          results: results,
          printer_class: printer_class,
        ).run

        Kettle::Drift::Outcome.new(
          project_root: expanded_project_root,
          files: selected_files,
          template_dir: expanded_template_dir,
          baseline_set: baseline_set,
          results: results,
          warning_count: warning_count,
          json_path: expanded_json_path,
          lock_path: expanded_lock_path,
          mode: mode,
          diff: process_result.diff,
          exit_code: process_result.exit_code,
        )
      end
    end
  end
end
