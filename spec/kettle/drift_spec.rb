# frozen_string_literal: true

require "rake"
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

  describe "rake tasks" do
    around do |example|
      original = Rake.application
      Rake.application = Rake::Application.new
      example.run
    ensure
      Rake.application = original
    end

    it "defines kettle:drift:update" do
      load File.expand_path("../../lib/kettle/drift/rakelib/drift.rake", __dir__)

      expect(Rake::Task.task_defined?("kettle:drift:validate")).to be(true)
      expect(Rake::Task.task_defined?("kettle:drift:update")).to be(true)
      expect(Rake::Task.task_defined?("kettle:drift")).to be(true)
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
