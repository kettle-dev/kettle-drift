# frozen_string_literal: true

module Kettle
  module Drift
    class Process
      class Printer
        def initialize(diff:, lock_path:, mode: :update)
          @diff = diff
          @lock_path = lock_path
          @mode = mode
        end

        def print_results
          send(:"print_#{diff.state}")
        end

        private

        attr_reader :diff, :lock_path, :mode

        def print_complete
          puts "Kettle Drift is complete!"
          puts "Removing `#{Kettle::Drift.display_path(lock_path)}` lock file..." if diff.statistics[:fixed].positive?
        end

        def print_updated
          if mode == :force_update
            puts "Kettle Drift found both fixed drift and new untracked drift, and is force-updating the lockfile."
          else
            puts "Kettle Drift found both fixed drift and new untracked drift."
          end
        end

        def print_no_changes
          puts "Kettle Drift got no changes."
        end

        def print_new
          puts "Kettle Drift got results for the first time. #{diff.statistics[:left]} drift item(s) found."
          puts "Don't forget to commit `#{Kettle::Drift.display_path(lock_path)}`."
        end

        def print_better
          puts "Kettle Drift got #{diff.statistics[:fixed]} drift item(s) fixed, #{diff.statistics[:left]} left. Keep going!"
        end

        def print_worse
          if mode == :force_update
            puts "Kettle Drift found new untracked drift and is force-updating the lockfile:"
          else
            puts "Uh oh, Kettle Drift got worse:"
          end
          diff.files.each do |file, entries|
            puts "-> #{Kettle::Drift.display_path(file)} (#{entries.size} new drift item(s))"
            entries.each do |entry|
              puts "    (lines #{entry[:lines].join(", ")}) #{entry[:chunk].inspect}"
            end
          end
        end
      end
    end
  end
end
