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

      def initialize(*)
        super

        @single_item_hash = false
      end

      def on_send(node)
        _receiver, _message, *args = *node
        remove_curly_braces_from_hash(args.first) if args.one? && args.first.type.equal?(:hash)

        super
      end

      def on_hash(node)
        format_multiline_hash(node) if node.children.size > 1

        @single_item_hash = node.children.size == 1
        super
        @single_item_hash = false
      end

      def on_pair(node)
        insert_before(node.loc.expression, ' ') unless @single_item_hash
        super
      end

      private

      def remove_curly_braces_from_hash(node)
        opening = node.loc.begin
        closing = node.loc.end

        first_child = node.children.first
        last_child = node.children.last

        if first_child
          opening = opening.join(first_child.loc.expression.begin.begin)
          closing = closing.join(last_child.loc.expression.end.end)
        end

        if node.children.size > 1
          replace(opening, "\n ")
          replace(closing, "\n")
        else
          remove(opening)
          remove(closing)
        end
      end

      def format_multiline_hash(node)
        insert_after(node.loc.begin, "\n")
        insert_newlines_between_pairs(node.children)
        align_hash_values(node.children)
        remove_trailing_space(node)
      end

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
