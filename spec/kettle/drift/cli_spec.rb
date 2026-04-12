# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

RSpec.describe Kettle::Drift::CLI do
  let(:exe_path) { File.expand_path("../../../exe/kettle-drift", __dir__) }

  it "creates a lockfile and report on first run" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "lib"))
      File.write(File.join(dir, "lib", "demo.rb"), <<~RUBY)
        alpha_line
        beta_line
        alpha_line
        beta_line
      RUBY

      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        exe_path,
        dir,
      )

      expect(status.success?).to be(true), "stdout=#{stdout}\nstderr=#{stderr}"
      expect(stderr).to eq("")
      expect(stdout).to include("drift warning")
      expect(stdout).to include("results for the first time")
      expect(File).to exist(File.join(dir, ".kettle-drift.lock"))
      expect(Dir.glob(File.join(dir, "tmp", "kettle-drift", "*.json"))).not_to be_empty
    end
  end

  it "fails in check mode when new drift appears beyond the lockfile" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "lib"))
      file = File.join(dir, "lib", "demo.rb")
      File.write(file, "alpha_line\nbeta_line\nalpha_line\nbeta_line\n")

      first_stdout, first_stderr, first_status = Open3.capture3(RbConfig.ruby, exe_path, dir)
      expect(first_status.success?).to be(true), "stdout=#{first_stdout}\nstderr=#{first_stderr}"

      File.write(file, <<~RUBY)
        alpha_line
        beta_line
        alpha_line
        beta_line
        gamma_line
        delta_line
        gamma_line
        delta_line
      RUBY

      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        exe_path,
        dir,
        "--check",
      )

      expect(status.success?).to be(false), "stdout=#{stdout}\nstderr=#{stderr}"
      expect(stderr).to eq("")
      expect(stdout).to include("Kettle Drift got worse")
    end
  end
end
