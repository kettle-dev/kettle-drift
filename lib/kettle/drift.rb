# frozen_string_literal: true

require "version_gem"
require_relative "drift/version"

Kettle::Drift::Version.class_eval do
  extend VersionGem::Basic
end
module Kettle
  module Drift
    class Error < StandardError; end
    # Your code goes here...
  end
end
