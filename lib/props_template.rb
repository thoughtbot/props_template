require "props_template/base"
require "props_template/extensions/partial_renderer"
require "props_template/extensions/cache"
require "props_template/extensions/deferment"
require "props_template/extensions/fragment"
require "props_template/base_with_extensions"
require "props_template/extension_manager"
require "active_support/core_ext/string/output_safety"
require "active_support/core_ext/array"
require "props_template/searcher"
require "props_template/handler"
require "props_template/options"
require "props_template/helper"
require "props_template/version"

require "active_support"

module Props
  class Template
    GENERATED_KEY_METHODS = Module.new
    include GENERATED_KEY_METHODS

    GENERATABLE_KEY_REGEXP = /\A[a-zA-Z_]\w*[!?]?\z/
    GENERATED_KEY_METHODS_LOCK = Mutex.new

    class << self
      attr_accessor :template_lookup_options
    end

    self.template_lookup_options = {handlers: [:props]}

    delegate :result!, :array!,
      :child!,
      :partial!,
      :extract!,
      :deferred!,
      :fragments!,
      :disable_deferments!,
      :set_content!,
      :traveled_path!,
      :fragment_context!,
      to: :builder!

    def initialize(context = nil, options = {})
      @builder = BaseWithExtensions.new(self, context, options)
      @context = context
      @fragment_context = nil
      @found_path = []
    end

    def set!(key, options = {}, &block)
      if block && (options[:search] || options[:dig]) && !@builder.is_a?(Searcher)
        search = options[:search] || options[:dig]

        prev_builder = @builder
        @builder = Searcher.new(self, search, @context)

        options.delete(:search)
        options.delete(:dig)

        @builder.set!(key, options, &block)
        found_block, found_path, found_options, fragment_path, fragment_context, found_item = @builder.found!
        @found_path = found_path || []
        @fragment_context = fragment_context
        @builder = prev_builder
        @fragment_path = fragment_path

        # An inline options object, e.g. `json.foo(with.partial("foo"))`, has
        # no block; its content comes from the options instead.
        found_inline_options = found_options.is_a?(Props::Options)

        if found_block || found_inline_options
          @builder.item_context = found_item
          set!(key, found_options, &found_block)
        end
      elsif block || options.is_a?(Props::Options)
        @builder.set!(key, options, &block)
      else
        @builder.set_value!(key, options)
      end
    end

    def partial!(**options)
      @context.render options
    end

    # Relative to the fragment the dig ended in, so the client can graft into
    # it; the full path when no fragment was crossed.
    def found_path!
      fragment_path = @fragment_path || []
      @found_path[fragment_path.size..].join(".")
    end

    def fragment_context!
      @fragment_context
    end

    def builder!
      @builder
    end

    def self.generate_key_method(key)
      GENERATED_KEY_METHODS_LOCK.synchronize do
        name = key.name
        already_implemented = method_defined?(key) || private_method_defined?(key)

        if !already_implemented && GENERATABLE_KEY_REGEXP.match?(name)
          GENERATED_KEY_METHODS.module_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{name}(options = {}, &block)
              set!(#{key.inspect}, options, &block)
            end
          RUBY
        end
      end
    end

    private

    # No respond_to_missing?: a builder accepts any key, but claiming to
    # respond to everything would answer yes to probes like to_ary or to_hash.
    # Generated methods are real methods, so respond_to? sees those already.
    def method_missing(key, ...) # standard:disable Style/MissingRespondToMissing
      self.class.generate_key_method(key)
      set!(key, ...)
    end
  end
end

require "props_template/railtie" if defined?(Rails)
