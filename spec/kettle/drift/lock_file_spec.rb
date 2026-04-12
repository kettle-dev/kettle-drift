# frozen_string_literal: true

require "tmpdir"
require "kettle/drift"

RSpec.describe Kettle::Drift::LockFile do
  it "round-trips serialized duplicate results" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      lock_file = described_class.new(lock_path)

      lock_file.write_results(
        {
          "alpha\nbeta" => [
            {file: File.join(dir, "lib/demo.rb"), lines: [4, 8]},
          ],
        },
        project_root: dir,
      )

      expect(lock_file.read_results).to eq(
        "alpha\nbeta" => [
          {file: "lib/demo.rb", lines: [4, 8]},
        ],
      )
    end
  end

  it "returns nil when the lock file does not exist" do
    Dir.mktmpdir do |dir|
      expect(described_class.new(File.join(dir, ".kettle-drift.lock")).read_results).to be_nil
    end
  end

  it "deletes an existing lock file" do
    Dir.mktmpdir do |dir|
      lock_path = File.join(dir, ".kettle-drift.lock")
      File.write(lock_path, "{}\n")

      described_class.new(lock_path).delete

      expect(File).not_to exist(lock_path)
    end
  end
end
