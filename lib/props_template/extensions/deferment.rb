module Props
  class Deferment
    attr_reader :deferred, :disabled

    def initialize(base, deferred = [])
      @deferred = deferred
      @base = base
      @disabled = false
    end

    def disable!
      @disabled = true
    end

    def refine_options(options, item = nil)
      options.clone
    end

    def extract_deferment_type(options, item)
      type, _ = [*options[:defer]]
      (Proc === type) ? type.call(item) : type
    end

    def handle(options, type, key, val)
      return if !options[:defer]

      _, rest = [*options[:defer]]
      rest ||= {
        placeholder: {}
      }

      placeholder = rest[:placeholder]
      success_action = rest[:success_action]
      fail_action = rest[:fail_action]

      if type.to_sym == :auto && key && val
        placeholder = {}
        placeholder[key] = val
      end

      request_path = @base.context.controller.request.fullpath
      path = @base.traveled_path.join(".")
      uri = ::URI.parse(request_path)
      qry = ::URI.decode_www_form(uri.query || "")
        .reject { |x| x[0] == "props_at" }
        .push(["props_at", path])

      uri.query = ::URI.encode_www_form(qry)

      deferral = {
        url: uri.to_s,
        path: path,
        type: type.to_s
      }

      # camelize for JS land
      deferral[:successAction] = success_action if success_action
      deferral[:failAction] = fail_action if fail_action

      @deferred.push(deferral)

      placeholder
    end
  end
end
