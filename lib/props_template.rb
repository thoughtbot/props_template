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
require "props_template/version"

require "active_support"

module Props
  class Template
    class << self
      attr_accessor :template_lookup_options
    end

    self.template_lookup_options = {handlers: [:props]}

    delegate :result!, :array!,
      :partial!,
      :extract!,
      :deferred!,
      :fragments!,
      :disable_deferments!,
      :set_block_content!,
      :traveled_path!,
      to: :builder!

    def initialize(context = nil, options = {})
      @builder = BaseWithExtensions.new(self, context, options)
      @context = context
    end

    def set!(key, options = {}, &block)
      if block && (options[:search] || options[:dig]) && !@builder.is_a?(Searcher)
        search = options[:search] || options[:dig]

        prev_builder = @builder
        @builder = Searcher.new(self, search, @context)

        options.delete(:search)
        options.delete(:dig)

        @builder.set!(key, options, &block)
        found_block, found_options = @builder.found!
        @builder = prev_builder

        if found_block
          set!(key, found_options, &found_block)
        end
      else
        @builder.set!(key, options, &block)
      end
    end

    def builder!
      @builder
    end

    alias_method :method_missing, :set!
    private :method_missing
  end
end

require "props_template/railtie" if defined?(Rails)
