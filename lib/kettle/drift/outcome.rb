# frozen_string_literal: true

module Kettle
  module Drift
    class Outcome
      attr_reader :project_root,
        :files,
        :template_dir,
        :baseline_set,
        :results,
        :warning_count,
        :json_path,
        :lock_path,
        :mode,
        :diff,
        :exit_code

      def initialize(
        project_root:,
        files:,
        template_dir:,
        baseline_set:,
        results:,
        warning_count:,
        json_path:,
        lock_path:,
        mode:,
        diff:,
        exit_code:
      )
        @project_root = project_root
        @files = files
        @template_dir = template_dir
        @baseline_set = baseline_set
        @results = results
        @warning_count = warning_count
        @json_path = json_path
        @lock_path = lock_path
        @mode = mode
        @diff = diff
        @exit_code = exit_code
      end

      def clean?
        results.empty?
      end
    end
  end
end
