# frozen_string_literal: true

require "prism/merge"

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
          desc("(stub) kettle:drift:validate is unavailable")
          task("kettle:drift:validate") do
            warn("NOTE: kettle-drift isn't installed, or is disabled for \#{RUBY_VERSION} in the current environment")
          end
          task("kettle:drift" => "kettle:drift:validate")
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
        merged = inject_rakefile_content(existing)
        return if merged == existing

        File.write(rakefile_path, merged)
        context.helpers.record_template_result(rakefile_path, :replace)
        context.out.report_detail("[kettle-drift] Injected Rakefile tasks")
      end

      def inject_rakefile_content(existing)
        return existing if existing.include?(SNIPPET_MARKER)

        injection_point = find_rakefile_injection_point(existing)
        return append_rakefile_snippet(existing) unless injection_point

        splice_rakefile_snippet(existing, injection_point)
      end

      def find_rakefile_injection_point(existing)
        analysis = Prism::Merge::FileAnalysis.new(
          existing,
          signature_generator: Kettle::Jem::Signatures.rakefile,
          source_label: "Rakefile",
        )
        return unless analysis.valid?

        statements = Ast::Merge::Navigable::Statement.build_list(analysis.statements)
        Ast::Merge::Navigable::InjectionPointFinder.new(statements).find(position: :after) do |statement|
          rakefile_signature(analysis, statement.node) == [:call, :require, "kettle/dev"]
        end
      rescue StandardError
        nil
      end

      def rakefile_signature(analysis, node)
        analysis.generate_signature(node)
      rescue StandardError
        nil
      end

      def splice_rakefile_snippet(existing, injection_point)
        lines = existing.lines
        start_line = statement_start_line(injection_point.anchor)
        end_line = expand_following_blank_lines(lines, statement_end_line(injection_point.anchor))
        replacement = lines[(start_line - 1)..(end_line - 1)].join + formatted_rakefile_snippet

        Ast::Merge::StructuralEdit::PlanSet.new(
          source: existing,
          plans: [
            Ast::Merge::StructuralEdit::SplicePlan.new(
              source: existing,
              replace_start_line: start_line,
              replace_end_line: end_line,
              replacement: replacement,
              metadata: {plugin: "kettle-drift", anchor: SNIPPET_MARKER},
            ),
          ],
          metadata: {plugin: "kettle-drift", anchor: SNIPPET_MARKER},
        ).merged_content
      end

      def expand_following_blank_lines(lines, line_number)
        last_line = line_number
        while blank_line?(lines[last_line])
          last_line += 1
        end
        last_line
      end

      def statement_start_line(statement)
        statement.start_line || statement.node&.location&.start_line
      end

      def statement_end_line(statement)
        statement.end_line || statement.node&.location&.end_line
      end

      def blank_line?(line)
        !line.nil? && line.strip.empty?
      end

      def formatted_rakefile_snippet
        RAKEFILE_SNIPPET.rstrip + "\n\n"
      end

      def append_rakefile_snippet(existing)
        body = existing.rstrip
        return RAKEFILE_SNIPPET.rstrip + "\n" if body.empty?

        body + "\n\n" + RAKEFILE_SNIPPET.rstrip + "\n"
      end
    end
  end
end
