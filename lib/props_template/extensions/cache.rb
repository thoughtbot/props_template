module Props
  class Cache
    delegate :controller, :safe_concat, to: :@context

    attr_reader :results

    def initialize(context)
      @context = context
      @results = {}
    end

    def self.normalize_options(options, item = nil)
      key, rest = [*options]
      rest ||= {}

      if item && ::Proc === key
        key = key.call(item)
      end

      [key, rest]
    end

    attr_reader :context

    def multi_fetch(keys, options = {})
      result = {}
      key_to_ckey = {}
      ckeys = []

      keys.each do |k|
        ckey = cache_key(k, options)
        ckeys.push(ckey)
        key_to_ckey[k] = ckey
      end

      payload = {
        controller_name: controller.controller_name,
        action_name: controller.action_name
      }

      read_caches = {}

      ActiveSupport::Notifications.instrument("read_multi_fragments.action_view", payload) do |payload|
        read_caches = ::Rails.cache.read_multi(*ckeys, options)
        payload[:read_caches] = read_caches
      end

      keys.each do |k|
        ckey = key_to_ckey[k]

        if read_caches[ckey]
          result[k] = read_caches[ckey]
        end
      end

      result
    end

    def load_cache(keys, options = {})
      @results = results.merge multi_fetch(keys, options)
    end

    # The below was copied from the wonderful jbuilder library Its also MIT
    # licensed, so no issues there.  Thanks to the jbuilder authors!

    def cache(key = nil, options = {})
      if controller.perform_caching
        cache_fragment_for(key, options) do
          yield
        end
      else
        yield
      end
    end

    def cache_fragment_for(key, options, &block)
      return results[key] if results[key]

      key = cache_key(key, options)
      read_fragment_cache(key, options) || write_fragment_cache(key, options, &block)
    end

    def read_fragment_cache(key, options = nil)
      controller.instrument_fragment_cache :read_fragment, key do
        ::Rails.cache.read(key, options)
      end
    end

    def write_fragment_cache(key, options = nil)
      controller.instrument_fragment_cache :write_fragment, key do
        yield.tap do |value|
          ::Rails.cache.write(key, value, options)
        end
      end
    end

    def cache_key(key, options)
      name_options = options.slice(:skip_digest, :virtual_path)
      key = @context.cache_fragment_name(key, **name_options)

      if @context.respond_to?(:combined_fragment_cache_key)
        key = @context.combined_fragment_cache_key(key)
      elsif ::Hash === key
        key = url_for(key).split("://", 2).last
      end

      ::ActiveSupport::Cache.expand_cache_key(key, :props)
    end
  end
end
