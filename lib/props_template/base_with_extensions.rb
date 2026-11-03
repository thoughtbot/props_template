module Props
  class BaseWithExtensions < Base
    attr_reader :builder, :context, :fragments, :deferred, :stream

    def initialize(builder, context = nil, options = {})
      @context = context
      @builder = builder
      @em = ExtensionManager.new(self)
      super()
    end

    def disable_deferments!
      @em.disable_deferments
    end

    def deferred!
      @em.deferred
    end

    def fragments!
      @em.fragments
    end

    def set_content!(options = {})
      return super if options.empty? || !@em.has_extensions(options)

      @em.handle(options, item_context) do
        yield
      end
    end

    def scoped_state
      prev_state = [@stream, @em.deferred, @em.fragments]
      @em = ExtensionManager.new(self)
      prev_scope = @scope
      @scope = nil

      yield @stream, @em.deferred, @em.fragments

      @scope = prev_scope
      @em = ExtensionManager.new(self, prev_state[1], prev_state[2])
    end

    def set!(key, options = {}, &block)
      if !block && options.is_a?(Props::Options)
        options.valid_for_set!
        super {}
      else
        super
      end
    end

    def handle_collection(collection, options)
      if options[:cache]
        key, rest = [*options[:cache]]

        if ::Proc === key
          cache_keys = collection.map do |item|
            key.call(item)
          end
          @em.load_cache(cache_keys, rest || {})
        end
      end

      super
    end
  end
end
