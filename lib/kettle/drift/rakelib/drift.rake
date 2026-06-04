# frozen_string_literal: true

namespace :kettle do
  namespace :drift do
    run_drift = lambda do |default_mode|
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
      template_dir = Kettle::Jem.template_root_path(project_root) if template_dir.to_s.strip.empty? && defined?(Kettle::Jem) && Kettle::Jem.respond_to?(:template_root_path)
      mode = if ENV["FORCE_UPDATE"].to_s == "true"
        :force_update
      elsif ENV["CHECK"].to_s == "true"
        :check
      elsif ENV["UPDATE"].to_s == "true"
        :update
      else
        default_mode
      end

      outcome = Kettle::Drift.run(
        project_root: project_root,
        template_dir: template_dir,
        min_chars: min_chars,
        json_path: ENV["JSON"],
        lock_path: lock_path,
        mode: mode
      )

      if outcome.clean?
        puts "[kettle-drift] ✅  No duplicate drift detected (min_chars=#{min_chars}, files=#{outcome.files.size}, baseline=#{outcome.baseline_set.size})"
      else
        puts "[kettle-drift] ⚠️  #{outcome.warning_count} drift warning(s) across #{outcome.results.size} unique chunk(s) (files=#{outcome.files.size}, baseline=#{outcome.baseline_set.size})"
        puts "[kettle-drift] 📄  Report: #{Kettle::Drift.display_path(outcome.json_path)}" if outcome.json_path
      end

      exit(outcome.exit_code)
    end

    desc "Check duplicate drift against the current lockfile without writing"
    task :check do
      run_drift.call(:check)
    end

    desc "Update duplicate drift lockfile when no new untracked drift appeared"
    task :update do
      run_drift.call(:update)
    end

    desc "Force-update duplicate drift and rewrite the lockfile even when new drift appeared"
    task :force_update do
      run_drift.call(:force_update)
    end
  end

  desc "Alias for kettle:drift:update"
  task drift: "drift:update"
end
