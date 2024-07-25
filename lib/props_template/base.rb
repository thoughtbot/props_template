require "oj"
require "active_support"

module Props
  class InvalidScopeForArrayError < StandardError; end

  class InvalidScopeForObjError < StandardError; end

  class Base
    attr_accessor :contains

    def initialize(encoder = nil)
      @stream = Oj::StringWriter.new(mode: :rails)
      @scope = nil
      @contains = nil
    end

    def set_block_content!(options = {})
      @scope = nil
      yield
      if @scope.nil?
        @stream.push_object
      end
      @stream.pop
    end

    def handle_set_block(key, options)
      key = format_key(key)
      @stream.push_key(key)
      set_block_content!(options) do
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

    def refine_item_options(item, options)
      options
    end

    def handle_collection_item(collection, item, index, options)
      set_block_content!(options) do
        yield
      end
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

    # builds structure of rendered optional attributes as hash
    def transform_contain_keys(values)
      return {} if values.blank?

      values.each_with_object({}) do |item, acc|
        if item.is_a?(Hash)
          item.each do |key, value|
            acc[key] = transform_contain_keys(value)
          end
        else
          acc[item] = :present
        end
      end
    end

    # todo, add ability to define contents of array
    def array!(collection, options = {})
      if @scope.nil?
        @scope = :array
        @stream.push_array
      else
        raise InvalidScopeForArrayError.new("array! expects exclusive use of this block")
      end

      handle_collection(collection, options) do |item, index|
        yield item, index
      end

      @scope = :array

      nil
    end

    # value should be lambda to avoid calculations before optional check
    # if attribute should be rendered then call set with calculated value
    def optional!(key, value = nil, &block)
      return set!(key, value ? value.call : {}, &block) if contains.blank?

      # traveled path without arra indexes
      path = traveled_path.select { |item| item.is_a?(Symbol) }
      # render if
      # 1) "contains" hash contains key at required nesting
      # 2) "contains" hash contains parent key at required nesting with all rendering attributes
      render_attribute = contains.dig(*(path + [key])) || path.size > 0 && contains.dig(*path) == {}

      set!(key, value ? value.call : {}, &block) if render_attribute
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
