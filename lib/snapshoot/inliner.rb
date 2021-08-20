module Snapshoot
  module Sexp
    private

    def s(type, *children)
      ::Parser::AST::Node.new(type, children)
    end
  end

  class ParsedSource
    include Concord.new(:ast)
    include Sexp

    def inline_snapshot_calls
      recursive_find(ast) do |node|
        node == s(:send, nil, :match_snapshot)
      end
    end

    private

    def recursive_find(node, &blk)
      return nil unless node.is_a?(Parser::AST::Node)
      return [node] if blk.call(node)

      node.children.map { |child| recursive_find(child, &blk) }.flatten.compact
    end
  end

  class Injector
    include Anima.new(:source, :lineno, :actual_value)
    include Memoizable

    def inject
      buffer = Parser::Source::Buffer.new('(source)', source: source)
      Rewriter.new(self).rewrite(buffer, source_ast)
    end

    def snapshot_call
      parsed_source.inline_snapshot_calls.find do |node|
        node.loc.line == lineno
      end
    end

    def parsed_source
      ParsedSource.new(source_ast)
    end
    memoize :source

    def source_ast
      Parser::CurrentRuby.parse(source)
    end
    memoize :source_ast

    def actual_sexp
      Serializer.serialize(actual_value)
    end
    memoize :actual_sexp

    class Rewriter < Parser::TreeRewriter
      include Concord.new(:injector)
      include Sexp

      def on_send(node)
        return super unless node == injector.snapshot_call

        replace(node.loc.expression, Unparser.unparse(injected_matcher))
      end

      private

      def injected_matcher
        s(:send, nil, :match_snapshot, injector.actual_sexp)
      end
    end
  end

  class Serializer
    include Concord.new(:value)
    include AbstractType
    include Sexp

    singleton_class.attr_accessor(:handlers)
    self.handlers = []

    NotSupported = Class.new(StandardError)

    def self.inherited(base)
      Serializer.handlers << base
    end

    def self.serialize(actual)
      inliner = handlers.find { |handler| handler.supports?(actual) }

      unless inliner
        raise NotSupported, <<~ERROR
          Not sure how to inline #{actual.inspect}!

          Supported inliners:

          #{handlers.map { |handler| " - #{handler}" }.join("\n")}
        ERROR
      end

      inliner.new(actual).serialize
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
