module Props
  class Fragment
    attr_reader :fragments

    def initialize(base, fragments = [])
      @base = base
      @fragments = fragments
    end

    def handle(options)
      return if !options[:partial]
      _partial_name, partial_opts = options[:partial]
      fragment = partial_opts[:fragment]

      if String === fragment || Symbol === fragment
        key = fragment.to_s
        path = @base.traveled_path.join(".")
        @name =key 

        @fragments.push(
          {id: key, path: path}
        )
      end
    end
  end
end
