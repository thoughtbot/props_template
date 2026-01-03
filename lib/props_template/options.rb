module Props
  class Options < Hash
    class InvalidOptionError < StandardError; end

    def partial(partial_name, opts = {})
      self[:partial] = [partial_name, opts]
      self
    end

    def defer(type, placeholder: {}, **opts)
      self[:defer] = [type, {placeholder: placeholder}.merge(opts)]
      self
    end

    def fragment(fragment)
      raise "Fragment can't be defined without a partial. Please use `partial` first" if !self[:partial]

      self[:partial][1][:fragment] = fragment
      self
    end

    def cache(id_or_block)
      return unless id_or_block

      self[:cache] = id_or_block
      self
    end

    def id_key(key_name)
      self[:key] = key_name
      self
    end

    def valid_for_set!
      raise InvalidOptionError.new("Props::Options can't be empty") if empty?
      raise InvalidOptionError.new("The partial option must be used with an inline `set!`") if !key?(:partial)
    end
  end
end
