module Props
  module LayoutPatch
    def render_template(view, template, layout_name, locals)
      if template.respond_to?(:handler) && template.handler == Props::Handler && layout_name
        prepend_formats(template.format)
        render_props_template(view, template, layout_name, locals)
      else
        super
      end
    end

    def render_props_template(view, template, path, locals)
      layout_locals = locals.dup
      layout_locals[:virtual_path_of_template] = template.virtual_path

      layout = resolve_props_layout(path, layout_locals.keys, [formats.first])
      body = if layout
        layout.render(view, layout_locals) do |json|
          template.render(view, locals)
        end
      else
        template.render(view, locals)
      end

      build_rendered_template(body, template)
    end

    def resolve_props_layout(layout, keys, formats)
      details = @details.dup
      details[:formats] = formats

      case layout
      when String
        begin
          if layout.start_with?("/")
            ActiveSupport::Deprecation.warn "Rendering layouts from an absolute path is deprecated."
            @lookup_context.with_fallbacks.find_template(layout, nil, false, [], details)
          else
            @lookup_context.find_template(layout, nil, false, [], details)
          end
        end
      when Proc
        resolve_props_layout(layout.call(@lookup_context, formats), keys, formats)
      else
        layout
      end
    end
  end
end

ActionView::TemplateRenderer.prepend(Props::LayoutPatch)
