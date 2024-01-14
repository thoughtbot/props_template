require "active_support"

module Props
  class Handler
    cattr_accessor :default_format
    self.default_format = :props

    def self.call(template, source = nil)
      source ||= template.source
      # this juggling is required to keep line numbers right in the error
      %{ __finalize = !defined?(@__json); @__json ||= Props::Template.new(self); json = @__json; #{source};
        json.result! if __finalize
      }
    end
  end
end
