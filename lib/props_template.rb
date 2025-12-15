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
require "props_template/version"

require "active_support"

module Props
  class Template
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
        found_block, found_path, found_options, fragment_path, fragment_context = @builder.found!
        @found_path = found_path || []
        @fragment_context = fragment_context
        @builder = prev_builder
        @fragment_path = fragment_path

        if found_block
          set!(key, found_options, &found_block)
        end
      else
        @builder.set!(key, options, &block)
      end
    end

    def partial!(**options)
      @context.render options
    end

    def found_path!
      @found_path[@fragment_path.size..].join(".")
    end

    def fragment_context!
      @fragment_context
    end

    def builder!
      @builder
    end

    alias_method :method_missing, :set!
    private :method_missing
  end
end

require "props_template/railtie" if defined?(Rails)
