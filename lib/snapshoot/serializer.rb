# frozen_string_literal: true

module Snapshoot
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
        Float   => :float,
        String  => :str,
        Symbol  => :sym
      }.freeze

      def self.supports?(value)
        MAP.key?(value.class)
      end

      def serialize
        s(MAP.fetch(value.class), value)
      end
    end

    class SingletonType < self
      MAP = {
        TrueClass  => :true,
        FalseClass => :false,
        NilClass   => :nil
      }.freeze

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
        s(
          :send,
          s(:const, nil, :Date), :new,
          s(:int, value.year),
          s(:int, value.month),
          s(:int, value.day)
        )
      end
    end

    class Time < self
      def self.supports?(value)
        value.instance_of?(::Time)
      end

      def serialize
        s(
          :send,
          s(:const, nil, :Time), :new,
          s(:int, value.year),
          s(:int, value.month),
          s(:int, value.day),
          s(:int, value.hour),
          s(:int, value.min),
          s(:int, value.sec),
          s(:str, value.strftime('%:z'))
        )
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
