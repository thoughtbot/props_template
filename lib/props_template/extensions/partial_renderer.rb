require 'action_view'

module Props
  class RenderedTemplate
    attr_reader :body, :layout, :template

    def initialize(body, layout, template)
      @body = body
      @layout = layout
      @template = template
    end

    def format
      template.format
    end
  end

  class Partialer
    INVALID_PARTIAL_MESSAGE = "The partial name must be a string, but received (%s)."
    OPTION_AS_ERROR_MESSAGE = "The value (%s) of the option `as` is not a valid Ruby identifier; " \
                               "make sure it starts with lowercase letter, " \
                               "and is followed by any combination of letters, numbers and underscores."
    IDENTIFIER_ERROR_MESSAGE = "The partial name (%s) is not a valid Ruby identifier; " \
                               "make sure your partial name starts with underscore."


    def initialize(base, context, builder)
      @context = context
      @builder = builder
      @base = base
    end

    def extract_details(options)
      registered_details.each_with_object({}) do |key, details|
        value = options[key]

        details[key] = Array(value) if value
      end
    end

    def registered_details
      if ActionView.version.to_s >= "7"
        ActionView::LookupContext.registered_details
      else
        @context.lookup_context.registered_details
      end
    end

    def find_and_add_template(all_options)
      first_opts = all_options[0]

      if first_opts[:partial]
        partial_opts = block_opts_to_render_opts(@builder, first_opts)
        template = find_template(partial_opts)

        all_options.map do |opts|
          opts[:_template] = template
          opts
        end
      else
        all_options
      end
    end

    def find_template(partial_opts)
      partial = partial_opts[:partial]
      template_keys = retrieve_template_keys(partial_opts)
      details = extract_details(partial_opts)

      prefixes = partial.include?(?/) ? [] : @context.lookup_context.prefixes
      @context.lookup_context.find_template(partial, prefixes, true, template_keys, details)
    end

    def retrieve_template_keys(options)
      template_keys = options[:locals].keys
      template_keys << options[:as] if options[:as]
      template_keys
    end

    def block_opts_to_render_opts(builder, options)
      partial, pass_opts = [*options[:partial]]
      pass_opts ||= {}
      pass_opts[:locals] ||= {}
      pass_opts[:partial] = partial
      pass_opts[:formats] = [:json]
      pass_opts.delete(:handlers)

      if !(String === partial)
        raise ArgumentError.new(INVALID_PARTIAL_MESSAGE % (partial.inspect))
      end

      pass_opts
    end

    def handle(options)
      partial_opts = block_opts_to_render_opts(@builder, options)
      template = options[:_template] || find_template(partial_opts)

      render_partial(template, @context, partial_opts)
    end

    def render_partial(template, view, options)
      instrument(:partial, identifier: template.identifier) do |payload|
        locals = options[:locals]
        content = template.render(view, locals)

        payload[:cache_hit] = view.view_renderer.cache_hits[template.virtual_path]
        build_rendered_template(content, template)
      end
    end

    def build_rendered_template(content, template, layout = nil)
      RenderedTemplate.new content, layout, template
    end

    def instrument(name, **options) # :doc:
      ActiveSupport::Notifications.instrument("render_#{name}.action_view", options) do |payload|
        yield payload
      end
    end

    def raise_invalid_option_as(as)
      raise ArgumentError.new(OPTION_AS_ERROR_MESSAGE % (as))
    end

    def raise_invalid_identifier(path)
      raise ArgumentError.new(IDENTIFIER_ERROR_MESSAGE % (path))
    end

    def retrieve_variable(path)
      base = path[-1] == "/" ? "" : File.basename(path)
      raise_invalid_identifier(path) unless base =~ /\A_?(.*?)(?:\.\w+)*\z/
      $1.to_sym
    end

    def refine_options(options, item = nil)
      return options if !options[:partial]

      partial, rest = [*options[:partial]]
      rest = (rest || {}).clone
      locals = rest[:locals] || {}
      rest[:locals] = locals

      if item
        as = if !rest[:as]
          retrieve_variable(partial)
        else
          rest[:as].to_sym
        end

        raise_invalid_option_as(as) unless /\A[a-z_]\w*\z/.match?(as.to_s)

        locals[as] = item

        if fragment_name = rest[:fragment]
          rest[:fragment] = fragment_name.to_s
        end
      end

      pass_opts = options.clone
      pass_opts[:partial] = [partial, rest]

      pass_opts
    end
  end
end
