module Props
  module PartialPatch
    def render(partial, context, block)
      template = find_template(partial, template_keys(partial))

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s, template_keys(partial))
      end

      if template.respond_to?(:handler) && template.handler == Props::Handler && layout
        render_partial_props_template(context, @locals, template, layout, block)
      else
        super
      end
    end

    def render_partial_props_template(view, locals, template, layout, block)
      ActiveSupport::Notifications.instrument(
        "render_partial.action_view",
        identifier: template.identifier,
        layout: layout && layout.virtual_path,
        locals: locals
      ) do |payload|
        body = if layout
          layout.render(view, locals, add_to_stack: !block) do |json|
            template.render(view, locals)
          end
        else
          template.render(view, locals)
        end

        build_rendered_template(body, template)
      end
    end
  end
end

ActionView::PartialRenderer.prepend(Props::PartialPatch)

