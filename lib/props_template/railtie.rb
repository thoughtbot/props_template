require "rails/railtie"
require "props_template"

module Props
  class Railtie < ::Rails::Railtie
    initializer :props_template do
      ActiveSupport.on_load :action_view do
        ActionView::Template.register_template_handler :props, Props::Handler
        ActionView::Base.include Props::Helper
        require "props_template/dependency_tracker"
        require "props_template/layout_patch"
        require "props_template/partial_patch"
      end
    end

    module ::ActionController
      module ApiRendering
        include ActionView::Rendering
      end
    end

    ActiveSupport.on_load :action_controller do
      if name == "ActionController::API"
        include ActionController::Helpers
        include ActionController::ImplicitRender
      end
    end
  end
end
