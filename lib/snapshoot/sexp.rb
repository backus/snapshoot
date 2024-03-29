# frozen_string_literal: true

module Snapshoot
  module Sexp
    private

    def s(type, *children)
      ::Parser::AST::Node.new(type, children)
    end
  end
end
