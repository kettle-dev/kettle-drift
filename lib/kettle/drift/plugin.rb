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
        insert_after_line = kettle_dev_anchor_end_line(content)
        if insert_after_line
          lines.insert(insert_after_line, "\n", RAKEFILE_SNIPPET, "\n")
          lines.join
        else
          [content.rstrip, "", RAKEFILE_SNIPPET.rstrip, ""].join("\n")
        end
      end

      def kettle_dev_anchor_end_line(content)
        prism_kettle_dev_anchor_end_line(content) || require_kettle_dev_line(content)
      end

      def prism_kettle_dev_anchor_end_line(content)
        require "prism"
        result = Prism.parse(content.to_s)
        return unless result.success?

        top_level_nodes = result.value.statements&.body.to_a
        anchor_node = top_level_nodes.reverse.find { |node| contains_kettle_dev_require?(node) }
        anchor_node&.location&.end_line
      rescue LoadError
        nil
      end

      def contains_kettle_dev_require?(node)
        return false unless node.respond_to?(:child_nodes)
        return true if kettle_dev_require_call?(node)

        node.child_nodes.compact.any? { |child| contains_kettle_dev_require?(child) }
      end

      def kettle_dev_require_call?(node)
        return false unless node.is_a?(Prism::CallNode)
        return false unless node.name == :require

        node.arguments&.arguments.to_a.any? do |argument|
          argument.is_a?(Prism::StringNode) && argument.unescaped == "kettle/dev"
        end
      end

      # This fallback is intentionally line-based because it is only used when
      # Prism is unavailable in the templating runtime.
      def require_kettle_dev_line(content)
        lines = content.lines
        require_index = lines.rindex { |line| line.strip == 'require "kettle/dev"' || line.strip == "require 'kettle/dev'" }
        return unless require_index

        block_start = lines[0..require_index].rindex { |line| line.strip == "begin" }
        return require_index + 1 unless block_start

        block_end = lines[block_start..].to_a.index { |line| line.strip == "end" }
        block_end ? block_start + block_end + 1 : require_index + 1
      end
    end
  end
end
