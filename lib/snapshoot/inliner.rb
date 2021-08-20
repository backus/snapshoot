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
    include Anima.new(:source_location, :actual_value)
    include Memoizable

    def inject
      puts 'inject....'
      binding.pry
    end

    def source
      ParsedSource.new(Parser::CurrentRuby.parse(source_file_raw))
    end
    memoize :source

    def source_file_raw
      source_path.read
    end
    memoize :source_file_raw

    def source_line
      source_location.lineno
    end

    def source_path
      Pathname.new(source_location.path)
    end

    def sexp
      Serializer.serialize(actual_value)
    end
    memoize :sexp
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
