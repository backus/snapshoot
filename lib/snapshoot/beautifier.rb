# frozen_string_literal: true

module Snapshoot
  class Beautifier
    include Memoizable
    include Concord.new(:source)

    def format
      buffer = Parser::Source::Buffer.new('(source)', source: source)
      Formatter.new(parsed_source).rewrite(buffer, parsed_source.ast)
    end

    def parsed_source
      ParsedSource.parse(source)
    end
    memoize :parsed_source

    class Formatter < Parser::TreeRewriter
      include Concord.new(:parsed_source)

      def on_hash(node)
        insert_after(node.loc.begin, "\n")
        insert_newlines_between_pairs(node.children)
        align_hash_values(node.children)
        remove_trailing_space(node)
        super
      end

      def on_pair(node)
        insert_before(node.loc.expression, ' ')
        super
      end

      private

      def remove_trailing_space(node)
        last_pair = node.children.last
        before_curly_end = node.loc.end.begin
        between_last_pair_and_curly = last_pair.loc.expression.end.join(before_curly_end)

        replace(between_last_pair_and_curly, "\n")
      end

      def align_hash_values(pairs)
        key_sizes =
          pairs.map do |pair|
            key = pair.children.first.loc.expression
            operator = pair.loc.operator
            key_operator_size = key.join(operator).size

            [pair, key_operator_size]
          end

        max_size = key_sizes.map(&:last).max

        key_sizes.each do |pair, key_size|
          added_space = max_size - key_size
          insert_after(pair.loc.operator, ' ' * added_space)
        end
      end

      def insert_newlines_between_pairs(pairs)
        token_spaces =
          pairs
            .each_cons(2)
            .map { |pair1, pair2| parsed_source.range_between(pair1, pair2) }

        commas = parsed_source.tokens.select(&:comma?)

        hash_commas =
          token_spaces.map do |range|
            commas.find { |comma_token| comma_token.range.contained?(range) }
          end

        hash_commas.each do |token|
          insert_after(token.range, "\n")
        end
      end
    end
  end
end
