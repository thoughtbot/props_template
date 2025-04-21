module Props
  class ExtensionManager
    attr_reader :base, :builder, :context

    def initialize(base, defered = [], fragments = [])
      @base = base
      @context = base.context
      @builder = base.builder
      @fragment = Fragment.new(base, fragments)
      @deferment = Deferment.new(base, defered)
      @partialer = Partialer.new(base, context, builder)
      @cache = Cache.new(@context)
    end

    def refine_options(options, item = nil)
      options = @partialer.refine_options(options, item)
      options = @deferment.refine_options(options, item)
      Cache.refine_options(options, item)
    end

    def refine_all_item_options(all_options)
      return all_options if all_options.empty?

      all_options = @partialer.find_and_add_template(all_options)
      @cache.multi_fetch_and_add_results(all_options)
    end

    def deferred
      @deferment.deferred
    end

    def fragments
      @fragment.fragments
    end

    def has_extensions(options)
      options[:defer] || options[:cache] || options[:partial] || options[:key]
    end

    def handle(options)
      return yield if !has_extensions(options)

      if options[:defer]
        placeholder = @deferment.handle(options)
        base.stream.push_value(placeholder)
        @fragment.handle(options)
      else
        handle_cache(options) do
          base.set_block_content! do
            if options[:partial]
              @fragment.handle(options)
              @partialer.handle(options)
            else
              yield
            end

            if options[:key]
              id, val = options[:key]
              base.set!(id, val)
            end
          end
        end
      end
    end

    private

    def handle_cache(options)
      if options[:cache]
        recently_cached = false

        state = @cache.cache(*options[:cache]) do
          recently_cached = true
          result = nil
          start = base.stream.to_s.length
          base.scoped_state { |stream, deferred_paths, fragment_paths|
            yield
            meta = Oj.dump([deferred_paths, fragment_paths]).strip
            json_in_progress = base.stream.to_s
            if json_in_progress[start] == ","
              start += 1
            end
            raw = base.stream.to_s[start..].strip
            result = "#{meta}\n#{raw}"
          }
          result
        end

        meta, raw_json = state.split("\n")
        next_deferred, next_fragments = Oj.load(meta)
        deferred.push(*next_deferred)
        fragments.push(*next_fragments)

        if !recently_cached
          base.stream.push_json(raw_json)
        end
      else
        yield
      end
    end
  end
end
