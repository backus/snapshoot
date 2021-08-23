module Snapshoot
  class Scheduler
    include Concord.new(:batches)

    def self.create
      new({})
    end

    private_class_method :new

    def write_changes
      batches.values.each do |batch|
        batch.write
      end
    end

    def schedule(path:, source_range:, replacement:)
      change = Change.new(source_range, replacement)

      batches[path] = batch_for(path).append_change(change)
    end

    private

    def batch_for(path)
      batches.fetch(path) do
        source = path.read
        buffer = Parser::Source::Buffer.new(path.to_s, source: source)

        Batch.new(
          path:    path,
          ast:     Parser::CurrentRuby.parse(source),
          buffer:  buffer,
          changes: []
        )
      end
    end

    class Batch
      include Anima.new(:path, :ast, :buffer, :changes)

      def append_change(change)
        with(changes: changes + [change])
      end

      def change_for(node)
        matching_change =
          changes.find do |change|
            node.loc.expression.to_range == change.source_range.to_range
          end

        return unless matching_change

        matching_change.replacement_source
      end

      def write
        path.write(Rewrite.new(self).rewrite(buffer, ast))
      end

      class Rewrite < Parser::TreeRewriter
        include Concord.new(:batch)

        def on_send(node)
          if (replacement = batch.change_for(node))
            replace(node.loc.expression, replacement)
          end

          super
        end
      end
    end

    class Change
      include Concord::Public.new(:source_range, :replacement_source)
    end
  end

  singleton_class.attr_accessor :scheduler
  self.scheduler = Scheduler.create
end
