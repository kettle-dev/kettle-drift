# frozen_string_literal: true

module Kettle
  module Drift
    class Process
      module CalculateDiff
        class << self
          def call(new_results, old_results)
            new_entries = flatten_results(new_results)
            return Kettle::Drift::Diff.new(state: :complete, fixed_entries: [], new_entries: [], unchanged_entries: []) if new_entries.empty? && old_results.nil?
            return Kettle::Drift::Diff.new(state: :new, new_entries: new_entries, unchanged_entries: []) if old_results.nil?

            old_entries = flatten_results(old_results)
            new_map = index_entries(new_entries)
            old_map = index_entries(old_entries)

            added = (new_map.keys - old_map.keys).map { |key| new_map.fetch(key) }
            fixed = (old_map.keys - new_map.keys).map { |key| old_map.fetch(key) }
            unchanged = (new_map.keys & old_map.keys).map { |key| new_map.fetch(key) }

            state = if new_entries.empty?
              :complete
            elsif added.empty? && fixed.empty?
              :no_changes
            elsif added.empty?
              :better
            elsif fixed.empty?
              :worse
            else
              :updated
            end

            Kettle::Drift::Diff.new(
              state: state,
              new_entries: added,
              fixed_entries: fixed,
              unchanged_entries: unchanged
            )
          end

          private

          def flatten_results(results)
            results.keys.sort.flat_map do |chunk|
              Array(results.fetch(chunk)).map do |entry|
                {
                  chunk: chunk,
                  file: entry.fetch(:file),
                  lines: entry.fetch(:lines)
                }
              end
            end
          end

          def index_entries(entries)
            entries.each_with_object({}) do |entry, indexed|
              indexed[entry_key(entry)] = entry
            end
          end

          def entry_key(entry)
            [entry.fetch(:chunk), entry.fetch(:file), Array(entry.fetch(:lines))]
          end
        end
      end
    end
  end
end
