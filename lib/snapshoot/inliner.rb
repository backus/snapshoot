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
    include Anima.new(:path, :source, :injections)
    include Memoizable
    include Sexp

    def self.from_spec(caller_location:, actual_value:)
      path = Pathname.new(caller_location.path)
      new(path: path, source: path.read, injections: { caller_location.lineno => actual_value })
    end

    def rewrite
      buffer = Parser::Source::Buffer.new('(source)', source: source)
      Rewriter.new(self).rewrite(buffer, source_ast)
    end

    def inject
      path.write(rewrite)
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

    private

    def klass
      value.class
    end

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

    class Date < self
      def self.supports?(value)
        value.instance_of?(::Date)
      end

      def serialize
        s(:send,
          s(:const, nil, :Date), :new,
          s(:int, value.year),
          s(:int, value.month),
          s(:int, value.day))
      end
    end

    class Time < self
      def self.supports?(value)
        value.instance_of?(::Time)
      end

      def serialize
        s(:send,
          s(:const, nil, :Time), :new,
          s(:int, value.year),
          s(:int, value.month),
          s(:int, value.day),
          s(:int, value.hour),
          s(:int, value.min),
          s(:int, value.sec),
          s(:str, value.strftime('%:z')))
      end
    end

    class AnimaObject < self
      def self.supports?(value)
        klass = value.class

        klass.respond_to?(:anima) && # Exposes anima attributes on class
          klass.respond_to?(:new) && # Does not have a non-standard private constructor
          klass.name                 # Is not an anonymous class
      end

      def serialize
        const = Parser::CurrentRuby.parse(klass.name)

        s(:send, const, :new, Serializer.serialize(anima_members))
      end

      private

      def anima_members
        klass.anima.attribute_names.map do |attribute_name|
          [attribute_name, value.instance_variable_get(:"@#{attribute_name}")]
        end.to_h
      end
    end

    class ConcordObject < self
      def self.supports?(value)
        klass = value.class

        klass.ancestors.grep(Concord).one? &&
          klass.respond_to?(:new)          &&
          klass.name
      end

      def serialize
        const = Parser::CurrentRuby.parse(klass.name)

        s(:send, const, :new, *positional_arguments)
      end

      private

      def positional_arguments
        concord_mixin.names.map do |name|
          Serializer.serialize(value.instance_variable_get(:"@#{name}"))
        end
      end

      def concord_mixin
        klass.ancestors.grep(Concord).first
      end
    end

    register Literal
    register SingletonType
    register Array
    register Hash
    register Date
    register Time
    register AnimaObject
    register ConcordObject
  end
end
