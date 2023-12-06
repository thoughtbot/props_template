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
      layout = resolve_layout(path, locals.keys, [formats.first])
      body = if layout
        layout.render(view, locals) do |json|
          template.render(view, locals)
        end
      else
        template.render(view, locals)
      end

      build_rendered_template(body, template)
    end
  end
end

ActionView::TemplateRenderer.prepend(Props::LayoutPatch)
