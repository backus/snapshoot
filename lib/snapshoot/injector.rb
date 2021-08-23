# frozen_string_literal: true

module Snapshoot
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
      ParsedSource.parse(source)
    end
    memoize :source

    def source_ast
      parsed_source.ast
    end

    def actual_sexp
      Serializer.serialize(actual_value)
    end
    memoize :actual_sexp

    class Rewriter < Parser::TreeRewriter
      include Concord.new(:injector)
      include Sexp

      def on_send(node)
        return super unless injector.snapshot_call?(node)

        replace(
          node.loc.expression,
          Unparser.unparse(injector.actual_sexp_for(node))
        )
      end
    end
  end
end
