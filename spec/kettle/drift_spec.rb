# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Kettle::Drift do
  it "has a version number" do
    expect(Kettle::Drift::VERSION).not_to be_nil
  end

  describe ".install_tasks" do
    it "loads kettle/drift/tasks.rb without error" do
      expect { described_class.install_tasks }.not_to raise_error
    end
  end

  describe ".target_files" do
    it "excludes hidden paths, temp content, and package artifacts" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, ".git", "objects"))
        FileUtils.mkdir_p(File.join(dir, "tmp"))
        FileUtils.mkdir_p(File.join(dir, "lib"))

        File.write(File.join(dir, ".git", "objects", "abc123"), "git object\n")
        File.write(File.join(dir, "tmp", "scratch.txt"), "temporary\n")
        File.binwrite(File.join(dir, "example-0.1.0.gem"), "\x1F\x8B\x08binary payload".b)
        kept = File.join(dir, "lib", "kept.rb")
        File.write(kept, "puts :ok\n")

        expect(described_class.target_files(project_root: dir)).to eq([kept])
      end
    end
  end
end
