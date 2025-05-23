module Props
  class Fragment
    attr_reader :fragments

    def initialize(base, fragments = [])
      @base = base
      @fragments = fragments
    end

    def handle(options)
      if options[:fragment]
        fragment_name, fragment_options = Array(options[:fragment])
        fragment_name = fragment_name.to_s

        path = @base.traveled_path.join(".")
        @name = fragment_name

        fragment = {type: fragment_name, path: path}

        if fragment_options
          fragment[:afterSave] = fragment_options[:after_save].to_s
          fragment[:options] = fragment_options[:options]
        end

        @fragments.push(fragment)
      end

      if options[:partial]
        _partial_name, partial_opts = options[:partial]
        fragment = partial_opts[:fragment]

        if String === fragment || Symbol === fragment
          fragment_name = fragment.to_s
          path = @base.traveled_path.join(".")
          @name = fragment_name

          @fragments.push(
            {type: fragment_name, path: path}
          )
        end
      end
    end
  end
end
