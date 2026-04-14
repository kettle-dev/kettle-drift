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
        result = Kettle::Jem::Crispr::Move.call(
          content: existing,
          source_target: Kettle::Jem::Crispr::Selectors.comment_region_owned_owner(
            marker: SNIPPET_MARKER,
            limit: {at_least: 0},
          ),
          destination: ->(crispr_context) { find_rakefile_injection_point(crispr_context) },
          replacement: RAKEFILE_SNIPPET,
          if_missing: :append,
          source_label: "Rakefile",
        )
        return if result.updated_content == existing

        File.write(rakefile_path, result.updated_content)
        context.helpers.record_template_result(rakefile_path, :replace)
        context.out.report_detail("[kettle-drift] Injected Rakefile tasks")
      end

      def find_rakefile_injection_point(existing_or_context)
        existing = if existing_or_context.respond_to?(:content)
          existing_or_context.content
        else
          existing_or_context
        end
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
    end
  end
end
