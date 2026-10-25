module Props
  # Already-encoded JSON, such as a cached fragment, for Oj to insert as is.
  # Oj calls raw_json on values when its use_raw_json option is on, and
  # takes the length from the String rather than scanning for it as
  # push_json does.
  class RawJSON
    def initialize(json)
      @json = json
    end

    def raw_json(depth, indent)
      @json
    end
  end
end
