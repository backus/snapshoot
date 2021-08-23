# frozen_string_literal: true

module Snapshoot
  class ParsedSource
    include Anima.new(:ast, :raw, :comments, :tokens)
    include Sexp

    def self.parse(raw)
      buffer = Parser::Source::Buffer.new('(source)', source: raw)
      ast, comments, tokens = Parser::CurrentRuby.new.tokenize(buffer)

      tokens
        .map! { |token| Token.from_parser(*token) }
        .sort_by!(&:begin_pos)

      new(
        ast:      ast,
        raw:      raw,
        comments: comments,
        tokens:   tokens
      )
    end

    def inline_snapshot_calls
      recursive_find(ast) do |node|
        node == s(:send, nil, :match_snapshot)
      end
    end

    # Exclusive range between two nodes. Does not overlap with the source ranges of either
    def range_between(node1, node2)
      node1.loc.expression.end.join(node2.loc.expression.begin)
    end

    private

    def recursive_find(node, &blk)
      return nil unless node.is_a?(Parser::AST::Node)
      return [node] if yield(node)

      node.children.map { |child| recursive_find(child, &blk) }.flatten.compact
    end

    class Token
      include Anima.new(:type, :source, :range)

      def self.from_parser(type, (source, range))
        new(
          type:   type,
          source: source,
          range:  range
        )
      end

      def begin_pos
        range.begin_pos
      end

      def comma?
        type == :tCOMMA
      end
    end
  end
end
