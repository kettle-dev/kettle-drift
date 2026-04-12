# frozen_string_literal: true

require_relative "process/calculate_diff"
require_relative "process/printer"

module Kettle
  module Drift
    class Process
      Result = Struct.new(:diff, :exit_code, keyword_init: true)

      attr_reader :project_root, :lock_file, :old_results, :new_results, :mode, :printer_class

      def initialize(project_root:, results:, lock_path:, mode: :update, printer_class: Kettle::Drift::Process::Printer)
        @project_root = File.expand_path(project_root)
        @lock_file = Kettle::Drift::LockFile.new(lock_path)
        @old_results = lock_file.read_results
        @new_results = Kettle::Drift::Serializer.normalize(results, project_root: @project_root)
        @mode = mode
        @printer_class = printer_class
      end

      def call
        run.exit_code
      end

      def run
        diff = Kettle::Drift::Process::CalculateDiff.call(new_results, old_results)
        printer_class&.new(diff: diff, lock_path: lock_file.path)&.print_results

        exit_code = error_code(diff)
        sync_lock_file(diff) if exit_code.zero?
        Result.new(diff: diff, exit_code: exit_code)
      end

      private

      def fail_with_outdated_lock?(diff)
        return false unless mode == :check
        return false if diff.state == :complete && old_results.nil?

        diff.state != :no_changes
      end

      def sync_lock_file(diff)
        return lock_file.delete if diff.state == :complete

        lock_file.write_results(new_results)
      end

      def error_code(diff)
        return 1 if fail_with_outdated_lock?(diff)
        return 1 if diff.state == :worse && mode != :force_update

        0
      end
    end
  end
end
