module Props
  class BaseWithExtensions < Base
    attr_reader :builder, :context, :fragments, :traveled_path, :deferred, :stream

    def initialize(builder, context = nil, options = {})
      @context = context
      @builder = builder
      @em = ExtensionManager.new(self)
      @traveled_path = []
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

    def traveled_path!
      @traveled_path.join(".")
    end

    def set_content!(options = {})
      return super if !@em.has_extensions(options)

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

    def format_key(key)
      key.to_s
    end

    def set!(key, options = {}, &block)
      if block || options.is_a?(Props::Options)
        options = @em.refine_options(options)
      end

      if !block && options.is_a?(Props::Options)
        options.valid_for_set!
        super {}
      else
        super
      end
    end

    def handle_set_block(key, options)
      n = 1
      if (suffix = options[:path_suffix])
        n += suffix.length
        @traveled_path.push(suffix)
      else
        @traveled_path.push(key)
      end

      super

      @traveled_path.pop(n)
      nil
    end

    def handle_collection_item(collection, item, index, options)
      if !options[:key]
        @traveled_path.push(index)
      else
        id, val = options[:key]

        if id.nil?
          @traveled_path.push(index)
        else
          @traveled_path.push("#{id}=#{val}")
        end
      end

      super

      @traveled_path.pop
      nil
    end

    def refine_all_item_options(all_options)
      @em.refine_all_item_options(all_options)
    end

    def refine_item_options(item, options)
      return options if options.empty?

      @em.refine_options(options, item)
    end
  end
end
