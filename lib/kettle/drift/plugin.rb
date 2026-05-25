# frozen_string_literal: true

module Kettle
  module Drift
    module Plugin
      module_function

      SNIPPET_MARKER = "### DUPLICATE DRIFT TASKS"

      RAKEFILE_SNIPPET = <<~RUBY
        ### DUPLICATE DRIFT TASKS
        begin
          require "kettle/drift"
          Kettle::Drift.install_tasks
        rescue LoadError
          desc("(stub) kettle:drift:check is unavailable")
          task("kettle:drift:check") do
            warn("NOTE: kettle-drift isn't installed, or is disabled for \#{RUBY_VERSION} in the current environment")
          end
          desc("(stub) kettle:drift:update is unavailable")
          task("kettle:drift:update") do
            warn("NOTE: kettle-drift isn't installed, or is disabled for \#{RUBY_VERSION} in the current environment")
          end
          desc("(stub) kettle:drift:force_update is unavailable")
          task("kettle:drift:force_update") do
            warn("NOTE: kettle-drift isn't installed, or is disabled for \#{RUBY_VERSION} in the current environment")
          end
          desc("(stub) kettle:drift is unavailable")
          task("kettle:drift" => "kettle:drift:update")
        end
      RUBY

      def register!(registrar)
        registrar.after_phase(:remaining_files) do |context:, **|
          inject_rakefile_tasks(context)
        end
      end

      def inject_rakefile_tasks(context)
        rakefile_path = File.join(context.project_root, "Rakefile")
        return unless File.exist?(rakefile_path)

        existing = File.read(rakefile_path)
        updated = upsert_rakefile_snippet(existing)
        return if updated == existing

        File.write(rakefile_path, updated)
        context.helpers.record_template_result(rakefile_path, :replace)
        context.out.report_detail("[kettle-drift] Injected Rakefile tasks")
      end

      def upsert_rakefile_snippet(content)
        if content.include?(SNIPPET_MARKER)
          return replace_existing_snippet(content)
        end

        insert_snippet(content)
      end

      def replace_existing_snippet(content)
        marker_index = content.index(SNIPPET_MARKER)
        next_section_index = content.index(/\n### [A-Z][^\n]*\n/, marker_index + SNIPPET_MARKER.length)
        prefix = content[0...marker_index].rstrip
        suffix = next_section_index ? content[next_section_index..].lstrip : ""
        "#{[prefix, RAKEFILE_SNIPPET.rstrip, suffix].reject(&:empty?).join("\n\n").rstrip}\n"
      end

      def insert_snippet(content)
        lines = content.lines
        require_index = lines.rindex { |line| line.match?(/^\s*require\s+["']kettle\/dev["']/) }
        if require_index
          lines.insert(require_index + 1, "\n", RAKEFILE_SNIPPET, "\n")
          lines.join
        else
          [content.rstrip, "", RAKEFILE_SNIPPET.rstrip, ""].join("\n")
        end
      end
    end
  end
end
