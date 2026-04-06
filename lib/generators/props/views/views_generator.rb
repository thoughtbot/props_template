require "rails/generators/named_base"
require "rails/generators/resource_helpers"

module Props
  module Generators
    class ViewsGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      source_root File.expand_path("../templates", __dir__)

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      def create_root_folder
        path = File.join("app/views", controller_file_path)
        empty_directory path unless File.directory?(path)
      end

      def copy_prop_files
        available_views.each do |view|
          @action_name = view
          filename = filename_with_extensions(view)
          template filename, File.join("app/views", controller_file_path, filename)
        end
      end

      protected

      def js_singular_table_name(casing = :lower)
        singular_table_name.camelize(casing)
      end

      def js_plural_table_name(casing = :lower)
        plural_table_name.camelize(casing)
      end

      def available_views
        %w[index show]
      end

      attr_reader :action_name

      def attributes_names
        [:id] + super
      end

      def filename_with_extensions(name)
        [name, :json, :props].join(".")
      end


      def attributes_list_with_timestamps
        attributes_list(attributes_names + %w[created_at updated_at])
      end

      def attributes_list(attributes = attributes_names)
        if self.attributes.any? { |attr| attr.name == "password" && attr.type == :digest }
          attributes = attributes.reject { |name| %w[password password_confirmation].include? name }
        end

        attributes
      end
    end
  end
end
