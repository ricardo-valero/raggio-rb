# frozen_string_literal: true

require_relative "raggio/schema/version"
require_relative "raggio/schema/type"
require_relative "raggio/schema/primitive"
require_relative "raggio/schema/composite"
require_relative "raggio/schema/base"
require_relative "raggio/schema/ast"
require_relative "raggio/schema/introspection"

module Raggio
  module Schema
    class Error < StandardError; end
  end
end
