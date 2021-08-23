# frozen_string_literal: true

module Snapshoot
  class ParsedSource
    include Anima.new(:ast, :raw, :comments, :tokens)
    include Sexp

    def self.parse(raw)
      buffer = Parser::Source::Buffer.new('(source)', source: raw)
      ast, comments, tokens = Parser::CurrentRuby.new.tokenize(buffer)

      new(
        ast:      ast,
        raw:      raw,
        comments: comments,
        tokens:   tokens.map { |token| Token.from_parser(*token) }
      )
    end

    def inline_snapshot_calls
      recursive_find(ast) do |node|
        node == s(:send, nil, :match_snapshot)
      end
    end

    private

    def recursive_find(node, &blk)
      return nil unless node.is_a?(Parser::AST::Node)
      return [node] if yield(node)

      node.children.map { |child| recursive_find(child, &blk) }.flatten.compact
    end

    class Token
      include Anima.new(:identifier, :source, :range)

      def self.from_parser(identifier, (source, range))
        new(
          identifier: identifier,
          source:     source,
          range:      range
        )
      end
    end
  end
end
