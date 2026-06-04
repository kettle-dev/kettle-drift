# frozen_string_literal: true

require "rake"
require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"

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

      expect(Rake::Task.task_defined?("kettle:drift:check")).to be(true)
      expect(Rake::Task.task_defined?("kettle:drift:validate")).to be(false)
      expect(Rake::Task.task_defined?("kettle:drift:update")).to be(true)
      expect(Rake::Task.task_defined?("kettle:drift:force_update")).to be(true)
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

    it "delegates to template-managed files when a template dir is configured" do
      Dir.mktmpdir do |dir|
        template_dir = File.join(dir, "template")
        FileUtils.mkdir_p(File.join(template_dir, "lib"))
        FileUtils.mkdir_p(File.join(dir, "lib"))
        managed = File.join(dir, "lib", "managed.rb")
        File.write(File.join(template_dir, "lib", "managed.rb.example"), "# template\n")
        File.write(managed, "puts :managed\n")
        File.write(File.join(dir, "lib", "ignored.rb"), "puts :ignored\n")

        expect(described_class.target_files(project_root: dir, template_dir: template_dir)).to eq([managed])
      end
    end
  end

  describe Kettle::Drift::Plugin do
    it "inserts drift tasks after kettle-dev rake tasks without Kettle/Jem internals" do
      rakefile = <<~RUBY
        require "bundler/gem_tasks"
        require "kettle/dev"

        task :default
      RUBY

      updated = described_class.upsert_rakefile_snippet(rakefile)

      expect(updated).to include(Kettle::Drift::Plugin::SNIPPET_MARKER)
      expect(updated.index('require "kettle/dev"')).to be < updated.index(Kettle::Drift::Plugin::SNIPPET_MARKER)
      expect(updated).to include('task("kettle:drift:check")')
    end

    it "inserts drift tasks after the full kettle-dev guarded block" do
      rakefile = <<~RUBY
        begin
          require "kettle/dev"
          Kettle::Dev.install_tasks unless Kettle::Dev::RUNNING_AS == "rake"
        rescue LoadError
          warn("NOTE: kettle-dev isn't installed")
        end

        ### TEMPLATING TASKS
        begin
          require "kettle/jem"
          Kettle::Jem.install_tasks
        rescue LoadError
          warn("NOTE: kettle-jem isn't installed")
        end
      RUBY

      updated = described_class.upsert_rakefile_snippet(rakefile)

      expect(updated).to include("Kettle::Dev.install_tasks")
      expect(updated.index("Kettle::Dev.install_tasks")).to be < updated.index(Kettle::Drift::Plugin::SNIPPET_MARKER)
      expect(updated.index(Kettle::Drift::Plugin::SNIPPET_MARKER)).to be < updated.index("### TEMPLATING TASKS")
      Dir.mktmpdir do |dir|
        rakefile = File.join(dir, "Rakefile")
        File.write(rakefile, updated)
        stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-c", rakefile)

        expect(status.success?).to be(true), "stdout=#{stdout}\nstderr=#{stderr}"
      end
    end

    it "replaces an existing drift task snippet" do
      rakefile = <<~RUBY
        require "kettle/dev"

        ### DUPLICATE DRIFT TASKS
        old

        ### TEMPLATING TASKS
        require "kettle/jem"
      RUBY

      updated = described_class.upsert_rakefile_snippet(rakefile)

      expect(updated).not_to include("old")
      expect(updated.scan(Kettle::Drift::Plugin::SNIPPET_MARKER).size).to eq(1)
      expect(updated).to include("### TEMPLATING TASKS")
      expect(updated).not_to end_with("\n\n")
    end

    it "locates the end of a guarded kettle-dev block without Prism" do
      rakefile = <<~RUBY
        begin
          require "kettle/dev"
          Kettle::Dev.install_tasks unless Kettle::Dev::RUNNING_AS == "rake"
        rescue LoadError
          warn("NOTE")
        end

        task :custom
      RUBY

      expect(described_class.require_kettle_dev_line(rakefile)).to eq(6)
    end

    it "falls back to the require line when the guarded block is incomplete" do
      rakefile = <<~RUBY
        task :setup
        require "kettle/dev"
      RUBY

      expect(described_class.require_kettle_dev_line(rakefile)).to eq(2)
      expect(described_class.require_kettle_dev_line("task :setup\n")).to be_nil
    end

    it "injects Rakefile tasks through the plugin context" do
      helpers = Class.new do
        attr_reader :changes

        def initialize
          @changes = []
        end

        def record_template_result(path, action)
          @changes << [path, action]
        end
      end.new
      output = Class.new do
        attr_reader :details

        def initialize
          @details = []
        end

        def report_detail(message)
          @details << message
        end
      end.new

      Dir.mktmpdir do |dir|
        rakefile = File.join(dir, "Rakefile")
        File.write(rakefile, "task :default\n")
        context = Struct.new(:project_root, :helpers, :out).new(dir, helpers, output)

        described_class.inject_rakefile_tasks(context)

        expect(File.read(rakefile)).to include(Kettle::Drift::Plugin::SNIPPET_MARKER)
        expect(helpers.changes).to eq([[rakefile, :replace]])
        expect(output.details).to eq(["[kettle-drift] Injected Rakefile tasks"])

        described_class.inject_rakefile_tasks(context)

        expect(helpers.changes.size).to eq(1)
      end
    end

    it "does not report plugin changes when the Rakefile is absent" do
      helpers = Class.new do
        attr_reader :changes

        def initialize
          @changes = []
        end

        def record_template_result(path, action)
          @changes << [path, action]
        end
      end.new
      output = Class.new do
        def report_detail(message)
        end
      end.new

      Dir.mktmpdir do |dir|
        context = Struct.new(:project_root, :helpers, :out).new(dir, helpers, output)

        described_class.inject_rakefile_tasks(context)

        expect(helpers.changes).to be_empty
      end
    end
  end
end
