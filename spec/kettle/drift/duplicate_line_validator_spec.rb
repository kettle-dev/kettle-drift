# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "kettle/drift/duplicate_line_validator"

RSpec.describe Kettle::Drift::DuplicateLineValidator do
  describe ".scan" do
    it "returns empty hash when no duplicates" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "clean.rb")
        File.write(path, "line one\nline two\nline three\n")
        expect(described_class.scan(files: [path])).to be_empty
      end
    end

    it "detects duplicate 2-line chunks in a single file" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "duped.rb")
        File.write(path, <<~RUBY)
          require "foo"
          require "bar"
          require "foo"
          require "bar"
          require "baz"
        RUBY

        results = described_class.scan(files: [path])
        expect(results).to have_key("require \"foo\"\nrequire \"bar\"")
        expect(results["require \"foo\"\nrequire \"bar\""].first).to eq(file: path, lines: [1, 3])
      end
    end

    it "ignores lines with <= min_chars non-whitespace characters" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "short.rb")
        File.write(path, "end\nend\nend\n")
        expect(described_class.scan(files: [path])).to be_empty
      end
    end

    it "suppresses markdown table header and separator pairs" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "README.md")
        File.write(path, <<~MD)
          | Variable | CLI Flag | Default | Description |
          |----------|----------|---------|-------------|
          | FOO      | --foo    | false   | enables foo |

          | Variable | CLI Flag | Default | Description |
          |----------|----------|---------|-------------|
          | BAR      | --bar    | true    | enables bar |
        MD

        expect(described_class.scan(files: [path])).to be_empty
      end
    end

    it "suppresses duplicate chunks inside markdown code fences" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "README.md")
        File.write(path, <<~MD)
          ```ruby
          require "my_gem"
          result = do_something
          ```

          ```ruby
          require "my_gem"
          result = do_something
          ```
        MD

        expect(described_class.scan(files: [path])).to be_empty
      end
    end

    it "suppresses consecutive ENV assignment pairs in Rakefiles" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Rakefile")
        File.write(path, <<~RUBY)
          task(:run_one) do
            ENV["K_SOUP_COV_MIN_HARD"] = "false"
            ENV["MAX_ROWS"] = "0"
          end

          task(:run_two) do
            ENV["K_SOUP_COV_MIN_HARD"] = "false"
            ENV["MAX_ROWS"] = "0"
          end
        RUBY

        expect(described_class.scan(files: [path])).to be_empty
      end
    end

    it "flags duplicate eval_gemfile chunks in non-Appraisals files" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Gemfile")
        File.write(path, <<~RUBY)
          eval_gemfile "modular/rspec.gemfile"
          eval_gemfile "modular/style.gemfile"
          eval_gemfile "modular/rspec.gemfile"
          eval_gemfile "modular/style.gemfile"
        RUBY

        expect(described_class.scan(files: [path])).to have_key(
          "eval_gemfile \"modular/rspec.gemfile\"\neval_gemfile \"modular/style.gemfile\"",
        )
      end
    end
  end

  describe ".scan_template_results" do
    it "only scans files with create or replace actions" do
      Dir.mktmpdir do |dir|
        written = File.join(dir, "written.rb")
        skipped = File.join(dir, "skipped.rb")
        File.write(written, "gem \"foo\"\ngem \"bar\"\ngem \"foo\"\ngem \"bar\"\n")
        File.write(skipped, "gem \"baz\"\ngem \"qux\"\ngem \"baz\"\ngem \"qux\"\n")

        results = described_class.scan_template_results(
          template_results: {
            written => {action: :replace},
            skipped => {action: :skip},
          },
        )

        expect(results).to have_key("gem \"foo\"\ngem \"bar\"")
        expect(results).not_to have_key("gem \"baz\"\ngem \"qux\"")
      end
    end
  end

  describe ".warning_count" do
    it "returns total duplicate entries" do
      results = {
        "line_a\nline_b" => [{file: "a.rb", lines: [1, 5]}, {file: "b.rb", lines: [2, 3]}],
        "line_c\nline_d" => [{file: "c.rb", lines: [10, 20]}],
      }

      expect(described_class.warning_count(results)).to eq(3)
    end
  end

  describe ".to_json" do
    it "produces valid JSON with normalized file paths" do
      json = described_class.to_json(
        "dup" => [
          {file: "/var/home/pboling/src/kettle-rb/tree_haver/CHANGELOG.md", lines: [10, 20]},
        ],
      )

      parsed = JSON.parse(json)
      expect(parsed["dup"].first["file"]).to eq("/home/pboling/src/kettle-rb/tree_haver/CHANGELOG.md")
    end
  end

  describe ".write_json" do
    it "writes JSON to disk" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "report.json")
        described_class.write_json({"line_a\nline_b" => [{file: "a.rb", lines: [1, 2]}]}, path)
        expect(File).to exist(path)
      end
    end
  end

  describe ".report_summary" do
    it "renders a markdown summary" do
      summary = described_class.report_summary(
        {"gem \"foo\"\ngem \"bar\"" => [{file: "/project/a.rb", lines: [1, 3]}]},
        project_root: "/project",
      )

      expect(summary).to include("Duplicate Line Report")
      expect(summary).to include("a.rb")
      expect(summary).to include("1, 3")
    end

    it "normalizes /var/home paths before rendering" do
      summary = described_class.report_summary(
        {
          "alpha\nbeta" => [
            {file: "/var/home/pboling/src/kettle-rb/tree_haver/CHANGELOG.md", lines: [782, 785]},
          ],
        },
      )

      expect(summary).to include("/home/pboling/src/kettle-rb/tree_haver/CHANGELOG.md")
      expect(summary).not_to include("/var/home/pboling/src/kettle-rb/tree_haver/CHANGELOG.md")
    end
  end

  describe ".baseline" do
    it "returns duplicated chunk contents from the template directory" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "a.yml.example"), "key: value\nother: thing\nkey: value\nother: thing\n")
        File.write(File.join(dir, "b.rb.example"), "unique_line_here\nanother_unique_line\n")

        result = described_class.baseline(template_dir: dir, min_chars: 6)
        expect(result).to include("key: value\nother: thing")
        expect(result).not_to include("unique_line_here\nanother_unique_line")
      end
    end

    it "returns empty set when no template directory exists" do
      expect(described_class.baseline(template_dir: "/nonexistent/path")).to eq(Set.new)
    end
  end

  describe ".subtract_baseline" do
    it "removes entries found in the baseline set" do
      results = {
        "gem \"foo\"\ngem \"bar\"" => [{file: "a.rb", lines: [1, 3]}],
        "unique_problem\nline_here_ok" => [{file: "c.rb", lines: [5, 10]}],
      }

      filtered = described_class.subtract_baseline(
        results,
        baseline_set: Set.new(["gem \"foo\"\ngem \"bar\""]),
      )

      expect(filtered).to have_key("unique_problem\nline_here_ok")
      expect(filtered).not_to have_key("gem \"foo\"\ngem \"bar\"")
    end
  end

  describe ".template_managed_files" do
    it "returns existing files that match template patterns" do
      Dir.mktmpdir do |dir|
        tpl_dir = File.join(dir, "template")
        FileUtils.mkdir_p(tpl_dir)
        File.write(File.join(tpl_dir, "Rakefile.example"), "# rake\n")
        File.write(File.join(tpl_dir, "missing.yml.example"), "key: val\n")

        proj_dir = File.join(dir, "project")
        FileUtils.mkdir_p(proj_dir)
        File.write(File.join(proj_dir, "Rakefile"), "# actual rake\n")

        files = described_class.template_managed_files(project_root: proj_dir, template_dir: tpl_dir)
        expect(files).to include(File.join(proj_dir, "Rakefile"))
        expect(files).not_to include(File.join(proj_dir, "missing.yml"))
      end
    end
  end
end
