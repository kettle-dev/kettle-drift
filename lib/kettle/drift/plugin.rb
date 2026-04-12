# frozen_string_literal: true

module Kettle
  module Drift
    module Plugin
      module_function

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
        merged = Kettle::Jem::SourceMerger.apply(
          strategy: :merge,
          src: RAKEFILE_SNIPPET,
          dest: existing,
          path: "Rakefile",
          file_type: :rakefile,
        )
        return if merged == existing

        File.write(rakefile_path, merged)
        context.helpers.record_template_result(rakefile_path, :replace)
        context.out.report_detail("[kettle-drift] Injected Rakefile tasks")
      end
    end
  end
end
