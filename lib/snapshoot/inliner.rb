module Snapshoot
  module Sexp
    private

    def s(type, *children)
      ::Parser::AST::Node.new(type, children)
    end
  end

  class Inliner
    include Concord.new(:value)
    include AbstractType
    include Sexp

    singleton_class.attr_accessor(:handlers)
    self.handlers = []

    NotSupported = Class.new(StandardError)

    def self.inherited(base)
      Inliner.handlers << base
    end

    def self.inline(actual, _callers)
      inliner = handlers.find { |handler| handler.supports?(actual) }

      unless inliner
        raise NotSupported, <<~ERROR
          Not sure how to inline #{actual.inspect}!

          Supported inliners:

          #{handlers.map { |handler| " - #{handler}" }.join("\n")}
        ERROR
      end

      sexp = inliner.new(actual).serialize
      puts "Inlines as: #{sexp}"

      binding.pry

      raise 'not done'
    end

    abstract_singleton_method :supports?
    abstract_method :serialize

    class Int < self
      def self.supports?(value)
        value.instance_of?(Integer)
      end

      def serialize
        s(:int, value)
      end
    end
  end
end
