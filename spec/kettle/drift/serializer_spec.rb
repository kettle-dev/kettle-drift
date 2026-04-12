# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "kettle/drift"

RSpec.describe Kettle::Drift::Serializer do
  describe ".serialize" do
    it "writes deterministic, project-relative JSON" do
      json = described_class.serialize(
        {
          "beta\nalpha" => [
            {file: "/workspace/demo/lib/b.rb", lines: [7, 9]},
          ],
          "alpha\nbeta" => [
            {file: "/workspace/demo/lib/a.rb", lines: [4, 8]},
            {file: "/workspace/demo/lib/c.rb", lines: [1, 3]},
          ],
        },
        project_root: "/workspace/demo",
      )

      parsed = JSON.parse(json)
      expect(parsed.keys).to eq(["alpha\nbeta", "beta\nalpha"])
      expect(parsed["alpha\nbeta"].map { |entry| entry["file"] }).to eq(["lib/a.rb", "lib/c.rb"])
    end
  end

  describe ".deserialize" do
    it "returns symbolized result entries" do
      result = described_class.deserialize(<<~JSON)
        {
          "alpha\\nbeta": [
            {"file": "lib/a.rb", "lines": [1, 3]}
          ]
        }
      JSON

      expect(result).to eq(
        "alpha\nbeta" => [
          {file: "lib/a.rb", lines: [1, 3]},
        ],
      )
    end

    it "raises on invalid top-level structure" do
      expect {
        described_class.deserialize("[]")
      }.to raise_error(Kettle::Drift::Error, /expected a JSON object/)
    end
  end
end
