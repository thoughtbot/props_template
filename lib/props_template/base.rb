require "oj"
require "active_support"

module Props
  class InvalidScopeForArrayError < StandardError; end

  class InvalidScopeForObjError < StandardError; end

  class InvalidScopeForChildError < StandardError; end

  class Base
    attr_accessor :item_context

    def initialize(encoder = nil)
      @stream = Oj::StringWriter.new(mode: :rails)
      @scope = nil
      @item_context = nil
    end

    def set_content!(options = {})
      @scope = nil
      @item_context = nil
      yield
      if @scope.nil?
        @stream.push_object
      end
      @stream.pop
    end

    def handle_set_block(key, options)
      key = format_key(key)
      @stream.push_key(key)
      set_content!(options) do
        yield
      end
    end

    def format_key(key)
      key.to_s
    end

    def set!(key, value = nil)
      if @scope == :array
        raise InvalidScopeForObjError.new("Attempted to set! on an array! scope")
      end

      if @scope.nil?
        @scope = :object
        @stream.push_object
      end

      if block_given?
        handle_set_block(key, value) do
          yield
        end
      else
        key = format_key(key)
        @stream.push_value(value, key)
      end

      @scope = :object

      nil
    end

    def handle_collection_item(collection, item, index, options)
      @item_context = item

      set_content!(options) do
        yield
      end
    end

    def handle_collection(collection, options)
      collection.each_with_index do |item, index|
        handle_collection_item(collection, item, index, options) do
          # todo: remove index?
          yield item, index
        end
      end
    end

    def array!(collection = nil, options = {})
      if @scope.nil?
        @scope = :array
        @stream.push_array
      else
        raise InvalidScopeForArrayError.new("array! expects exclusive use of this block")
      end

      if block_given?
        if collection.nil?
          @child_index = nil
          yield
        else
          handle_collection(collection, options) do |item, index|
            yield item, index
          end
        end
      elsif options.is_a?(Props::Options)
        options.valid_for_set!
        handle_collection(collection, options) {}
      else
        raise ArgumentError.new("array! requires a block when no Props::Options object is given")
      end

      @scope = :array

      nil
    end

    # json.id item.id
    # json.value item.value
    #
    # json.extract! item, :id, :value
    #
    # with key transformation
    # json.extract! item, :id, [:first_name, :firstName]
    def extract!(object, *values)
      values.each do |value|
        key, attribute = if value.is_a?(Array)
          [value[1], value[0]]
        else
          [value, value]
        end

        set!(
          key,
          object.is_a?(Hash) ? object.fetch(attribute) : object.public_send(attribute)
        )
      end
    end

    def child!(options = {})
      if @scope != :array
        raise InvalidScopeForChildError.new("child! can only be used in a `array!` with no arguments")
      end

      if !block_given?
        raise ArgumentError.new("child! requires a block")
      end

      inner_scope = @scope
      child_index = @child_index || -1
      child_index += 1

      # this changes the scope to nil so child in a child will break
      set_content!(options) do
        yield
      end

      @scope = inner_scope
      @child_index = child_index
    end

    def result!
      if @scope.nil?
        @stream.push_object
      end
      @stream.pop

      json = @stream.raw_json
      @stream.reset

      @scope = nil
      json
    end
  end
end
