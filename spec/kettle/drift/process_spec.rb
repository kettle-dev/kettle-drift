# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "kettle/drift"

RSpec.describe Kettle::Drift::Process do
  def sample_results(root, line_sets)
    line_sets.each_with_object({}) do |(chunk, rel_path, lines), results|
      results[chunk] ||= []
      results[chunk] << {file: File.join(root, rel_path), lines: lines}
    end
  end

  it "creates the lockfile on first run" do
    Dir.mktmpdir do |dir|
      process = described_class.new(
        project_root: dir,
        lock_path: File.join(dir, ".kettle-drift.lock"),
        results: sample_results(dir, [["alpha\nbeta", "lib/a.rb", [1, 3]]])
      )

      expect { expect(process.call).to eq(0) }.to output(/results for the first time/).to_stdout
      expect(File).to exist(File.join(dir, ".kettle-drift.lock"))
    end
  end

  it "reports no changes when current results match the lockfile" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {"alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}]}
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        results: sample_results(dir, [["alpha\nbeta", "lib/a.rb", [1, 3]]])
      )

      expect { expect(process.call).to eq(0) }.to output(/got no changes/).to_stdout
    end
  end

  it "returns an error when new drift is introduced" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {"alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}]}
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        results: sample_results(
          dir,
          [
            ["alpha\nbeta", "lib/a.rb", [1, 3]],
            ["gamma\ndelta", "lib/b.rb", [4, 8]]
          ]
        )
      )

      expect { expect(process.call).to eq(1) }.to output(/Kettle Drift got worse/).to_stdout
      expect(File.read(lock_path)).not_to include("lib/b.rb")
    end
  end

  it "returns an error when drift both improves and introduces new entries" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {
          "alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}],
          "legacy\nchunk" => [{file: "lib/old.rb", lines: [2, 6]}]
        }
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        results: sample_results(
          dir,
          [
            ["alpha\nbeta", "lib/a.rb", [1, 3]],
            ["gamma\ndelta", "lib/b.rb", [4, 8]]
          ]
        )
      )

      expect { expect(process.call).to eq(1) }.to output(/both fixed drift and new untracked drift/).to_stdout
      expect(File.read(lock_path)).to include("lib/old.rb")
      expect(File.read(lock_path)).not_to include("lib/b.rb")
    end
  end

  it "updates the lockfile when drift is reduced" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {
          "alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}],
          "gamma\ndelta" => [{file: "lib/b.rb", lines: [4, 8]}]
        }
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        results: sample_results(dir, [["alpha\nbeta", "lib/a.rb", [1, 3]]])
      )

      expect { expect(process.call).to eq(0) }.to output(/1 drift item\(s\) fixed, 1 left/).to_stdout
      expect(File.read(lock_path)).not_to include("lib/b.rb")
    end
  end

  it "deletes the lockfile when no drift remains" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {"alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}]}
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        results: {}
      )

      expect { expect(process.call).to eq(0) }.to output(/Kettle Drift is complete!/).to_stdout
      expect(File).not_to exist(lock_path)
    end
  end

  it "fails in check mode when the lockfile is outdated" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {"alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}]}
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        mode: :check,
        results: sample_results(
          dir,
          [
            ["alpha\nbeta", "lib/a.rb", [1, 3]],
            ["gamma\ndelta", "lib/b.rb", [4, 8]]
          ]
        )
      )

      expect(process.call).to eq(1)
      expect(File.read(lock_path)).not_to include("lib/b.rb")
    end
  end

  it "updates in force-update mode when drift gets worse" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {"alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}]}
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        mode: :force_update,
        results: sample_results(
          dir,
          [
            ["alpha\nbeta", "lib/a.rb", [1, 3]],
            ["gamma\ndelta", "lib/b.rb", [4, 8]]
          ]
        )
      )

      expect(process.call).to eq(0)
      expect(File.read(lock_path)).to include("lib/b.rb")
    end
  end

  it "updates in force-update mode when drift is mixed" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      Kettle::Drift::LockFile.new(lock_path).write_results(
        {
          "alpha\nbeta" => [{file: "lib/a.rb", lines: [1, 3]}],
          "legacy\nchunk" => [{file: "lib/old.rb", lines: [2, 6]}]
        }
      )

      process = described_class.new(
        project_root: dir,
        lock_path: lock_path,
        mode: :force_update,
        results: sample_results(
          dir,
          [
            ["alpha\nbeta", "lib/a.rb", [1, 3]],
            ["gamma\ndelta", "lib/b.rb", [4, 8]]
          ]
        )
      )

      expect(process.call).to eq(0)
      lock_contents = File.read(lock_path)
      expect(lock_contents).to include("lib/b.rb")
      expect(lock_contents).not_to include("lib/old.rb")
    end
  end
end
