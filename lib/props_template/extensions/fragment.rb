module Props
  class Fragment
    attr_reader :fragments

    def initialize(base, fragments = [])
      @base = base
      @fragments = fragments
    end

    def self.fragment_name_from_options(options)
      return if !options[:partial]

      _, partial_opts = [*options[:partial]]
      return unless partial_opts

      fragment = partial_opts[:fragment]

      if String === fragment || Symbol === fragment
        fragment.to_s
      end
    end

    def handle(options)
      fragment_name = self.class.fragment_name_from_options(options)
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
