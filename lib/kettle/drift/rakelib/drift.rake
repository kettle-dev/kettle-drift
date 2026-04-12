# frozen_string_literal: true

namespace :kettle do
  namespace :drift do
    desc "Validate duplicate drift and sync the lockfile"
    task :validate do
      require "kettle/drift"
      begin
        require "kettle/jem"
      rescue LoadError
        nil
      end

      project_root = ENV.fetch("PROJECT_ROOT", Dir.pwd)
      min_chars = ENV.fetch("MIN_CHARS", Kettle::Drift::DuplicateLineValidator::DEFAULT_MIN_CHARS).to_i
      lock_path = ENV.fetch("LOCKFILE", File.join(project_root, Kettle::Drift::DEFAULT_LOCKFILE))
      template_dir = ENV["TEMPLATE_DIR"]
      template_dir = Kettle::Jem::DuplicateLineValidator.kettle_template_dir if template_dir.to_s.strip.empty? && defined?(Kettle::Jem::DuplicateLineValidator)
      mode = if ENV["FORCE_UPDATE"].to_s == "true"
        :force_update
      elsif ENV["CHECK"].to_s == "true"
        :check
      else
        :update
      end

      outcome = Kettle::Drift.run(
        project_root: project_root,
        template_dir: template_dir,
        min_chars: min_chars,
        json_path: ENV["JSON"],
        lock_path: lock_path,
        mode: mode,
      )

      if outcome.clean?
        puts "[kettle-drift] ✅  No duplicate drift detected (min_chars=#{min_chars}, files=#{outcome.files.size}, baseline=#{outcome.baseline_set.size})"
      else
        puts "[kettle-drift] ⚠️  #{outcome.warning_count} drift warning(s) across #{outcome.results.size} unique chunk(s) (files=#{outcome.files.size}, baseline=#{outcome.baseline_set.size})"
        puts "[kettle-drift] 📄  Report: #{Kettle::Drift.display_path(outcome.json_path)}" if outcome.json_path
      end

      exit(outcome.exit_code)
    end
  end

  desc "Alias for kettle:drift:validate"
  task drift: "drift:validate"
end
