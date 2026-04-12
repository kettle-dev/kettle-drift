# frozen_string_literal: true

RSpec.describe Kettle::Drift do
  it "has a version number" do
    expect(Kettle::Drift::VERSION).not_to be_nil
  end

  describe ".install_tasks" do
    it "loads kettle/drift/tasks.rb without error" do
      expect { described_class.install_tasks }.not_to raise_error
    end
  end
end
