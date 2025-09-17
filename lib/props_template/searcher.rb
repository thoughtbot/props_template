module Props
  class Searcher
    attr_reader :builder, :context, :fragments, :traveled_path

    def initialize(builder, path = [], context = nil)
      @search_path = path
      @depth = 0
      @context = context
      @found_block = nil
      @found_options = nil
      @builder = builder
      @traveled_path = []
      @partialer = Partialer.new(self, context, builder)
      @fragment_name = nil
    end

    def deferred!
      []
    end

    def fragments!
      []
    end

    def found!
      pass_opts = @found_options.clone || {}
      pass_opts.delete(:defer)
      traveled_path = @traveled_path || []
      if !traveled_path.empty?
        pass_opts[:path_suffix] = traveled_path
      end

      fragment_name = Fragment.fragment_name_from_options(pass_opts)
      if fragment_name
        @fragment_name = fragment_name
        @traveled_path = []
      end

      fragment_context = @fragment_name
      [@found_block, @traveled_path, pass_opts, fragment_context]
    end

    def set_block_content!(*args)
      yield
    end

    def set!(key, options = {}, &block)
      return if @found_block || !block

      if @search_path[@depth] == key.to_s
        @traveled_path.push(key)

        if @depth == @search_path.size - 1
          @found_options = options
          @found_block = block
          return
        end

        @depth += 1
        if options[:partial]
          fragment_name = Fragment.fragment_name_from_options(options)
          if fragment_name
            @fragment_name = fragment_name
            @traveled_path = []
          end

          @partialer.handle(options)
        else
          yield
        end
        @depth -= 1
      end

      nil
    end

    def array!(collection = nil, options = {}, &block)
      return if @found_block

      if collection.nil?
        # Handle child! mode - initialize child_index for searching
        @child_index = nil
        yield
      else
        # Original collection handling
        key_index = @search_path[@depth]
        id_name, id_val = key_index.to_s.split("=")

        if id_val
          id_val = id_val.to_i
          item = collection.member_by(id_name, id_val)
        else
          index = id_name.to_i
          item = collection.member_at(index)
        end

        if item
          pass_opts = @partialer.refine_options(options, item)
          @traveled_path.push(key_index)

          if @depth == @search_path.size - 1
            @found_options = pass_opts
            @found_block = proc {
              yield item, 0
            }
            return
          end

          @depth += 1
          if pass_opts[:partial]
            fragment_name = Fragment.fragment_name_from_options(pass_opts)
            if fragment_name
              @fragment_name = fragment_name
              @traveled_path = []
            end
            # todo: what happens when cached: true is passed?
            # would there be any problems with not using the collection_rende?
            @partialer.handle(pass_opts)
          else
            yield item, 0
          end
          @depth -= 1
        end
      end
    end

    def child!(options = {}, &block)
      return if @found_block

      child_index = @child_index || -1
      child_index += 1

      key_index = @search_path[@depth]
      target_index = key_index.to_i

      if child_index == target_index
        @traveled_path.push(key_index)

        if @depth == @search_path.size - 1
          @found_options = {}
          @found_block = block
          return
        end

        @depth += 1
        yield
        @depth -= 1
      end

      @child_index = child_index
    end
  end
end
