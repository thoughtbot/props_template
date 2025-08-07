require "oj"
require "active_support"

module Props
  class InvalidScopeForArrayError < StandardError; end

  class InvalidScopeForObjError < StandardError; end

  class InvalidScopeForChildError < StandardError; end

  class Base
    def initialize(encoder = nil)
      @result = nil
      @scope = nil
    end

    def set_block_content!(options = {})
      @scope = nil
      @result = nil
      yield
      if @scope.nil?
        @result = {}
      end
    end

    def handle_set_block(key, options)
      key = format_key(key)
      result = @result
      set_block_content!(options) do
        yield
      end
      result[key] = @result
      @result = result
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
        @result = {}
      end

      if block_given?
        handle_set_block(key, value) do
          yield
        end
      else
        key = format_key(key)
        @result[key] = value
      end

      @scope = :object

      nil
    end

    def refine_item_options(item, options)
      options
    end

    def handle_collection_item(collection, item, index, options)
      result = @result
      set_block_content!(options) do
        yield
      end
      result[index] = @result
      @result = result
    end

    def refine_all_item_options(all_options)
      all_options
    end

    def handle_collection(collection, options)
      all_opts = collection.map do |item|
        refine_item_options(item, options.clone)
      end

      all_opts = refine_all_item_options(all_opts)

      collection.each_with_index do |item, index|
        pass_opts = all_opts[index]
        handle_collection_item(collection, item, index, pass_opts) do
          # todo: remove index?
          yield item, index
        end
      end
    end

    def array!(collection = nil, options = {})
      if @scope.nil?
        @scope = :array
        @result = []
      else
        raise InvalidScopeForArrayError.new("array! expects exclusive use of this block")
      end

      if collection.nil?
        @child_index = nil
        yield
      else
        handle_collection(collection, options) do |item, index|
          yield item, index
        end
      end

      @scope = :array

      nil
    end

    def partial!(**options)
      @context.render options
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

      result = @result
      # this changes the scope to nil so child in a child will break
      set_block_content!(options) do
        yield
      end
      result[child_index] = @result
      @result = result

      @scope = inner_scope
      @child_index = child_index
    end

    def result!
      if @scope.nil?
        "{}"
      else
        JSON.generate(@result)
      end
    end
  end
end
