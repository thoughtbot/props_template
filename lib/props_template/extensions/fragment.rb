module Props
  class Fragment
    attr_reader :fragments

    def initialize(base, fragments = [])
      @base = base
      @fragments = fragments
    end

    def self.fragment_name_from_options(options, item = nil)
      return if !options[:partial]

      _, partial_opts = [*options[:partial]]
      return unless partial_opts

      fragment = partial_opts[:fragment]

      if item && ::Proc === fragment
        fragment = fragment.call(item)
      end

      if String === fragment || Symbol === fragment
        fragment.to_s
      end
    end

    def handle(options, item_context = nil)
      fragment_name = self.class.fragment_name_from_options(options, item_context)
      path = @base.traveled_path
        .map { |item| item.is_a?(Array) ? item[0] : item }
        .join(".")

      if fragment_name
        @fragments.push(
          {id: fragment_name, path: path}
        )
      end
    end
  end
end
