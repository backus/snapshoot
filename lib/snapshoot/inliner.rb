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
    include Anima.new(:source, :injections)
    include Memoizable
    include Sexp

    def inject
      buffer = Parser::Source::Buffer.new('(source)', source: source)
      Rewriter.new(self).rewrite(buffer, source_ast)
    end

    def snapshot_call?(node)
      node == s(:send, nil, :match_snapshot) && injections.key?(node.loc.line)
    end

    def actual_sexp_for(node)
      actual_value = injections.fetch(node.loc.line)
      s(:send, nil, :match_snapshot, Serializer.serialize(actual_value))
    end

    def snapshot_call
      parsed_source.inline_snapshot_calls.find do |node|
        injections.key?(node.loc.line)
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
        return super unless injector.snapshot_call?(node)

        replace(node.loc.expression, Unparser.unparse(injector.actual_sexp_for(node)))
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

    def self.register(serializer)
      handlers << serializer
    end

    def self.serialize(actual)
      inliner = handlers.find { |handler| handler.supports?(actual) }

      unless inliner
        raise NotSupported, <<~ERROR
          Not sure how to inline #{actual.inspect} (#{actual.class.inspect})!

          Supported inliners:

          #{handlers.map { |handler| " - #{handler}" }.join("\n")}
        ERROR
      end

      inliner.new(actual).serialize
    end

    abstract_singleton_method :supports?
    abstract_method :serialize

    class Literal < self
      MAP = {
        Integer => :int,
        Float => :float,
        String => :str,
        Symbol => :sym
      }

      def self.supports?(value)
        MAP.key?(value.class)
      end

      def serialize
        s(MAP.fetch(value.class), value)
      end
    end

    class SingletonType < self
      MAP = {
        TrueClass => :true,
        FalseClass => :false,
        NilClass => :nil
      }

      def self.supports?(value)
        MAP.key?(value.class)
      end

      def serialize
        s(MAP.fetch(value.class))
      end
    end

    class Array < self
      def self.supports?(value)
        value.instance_of?(::Array)
      end

      def serialize
        s(:array, *members)
      end

      private

      def members
        value.map do |member|
          Serializer.serialize(member)
        end
      end
    end

    class Hash < self
      def self.supports?(value)
        value.instance_of?(::Hash)
      end

      def serialize
        s(:hash, *pairs)
      end

      private

      def pairs
        value.map do |key, value|
          s(:pair, Serializer.serialize(key), Serializer.serialize(value))
        end
      end
    end

    register Literal
    register SingletonType
    register Array
    register Hash
  end
end
