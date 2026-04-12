# frozen_string_literal: true

module Kettle
  module Drift
    class Diff
      attr_reader :state, :new_entries, :fixed_entries, :unchanged_entries

      def initialize(state:, new_entries: [], fixed_entries: [], unchanged_entries: [])
        @state = state
        @new_entries = new_entries
        @fixed_entries = fixed_entries
        @unchanged_entries = unchanged_entries
      end

      def statistics
        {
          left: unchanged_entries.size + new_entries.size,
          fixed: fixed_entries.size,
          new: new_entries.size,
          unchanged: unchanged_entries.size,
        }
      end

      def files
        new_entries.group_by { |entry| entry[:file] }
      end
    end
  end
end
