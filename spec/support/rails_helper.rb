require "active_support"
require "active_support/core_ext/array/access"
require "active_support/core_ext/class/attribute_accessors"
require "active_support/cache/memory_store"
require "active_support/json"
require "minitest"

require "action_view"
require "action_view/testing/resolvers"
require "action_view/template/resolver"
require "action_dispatch"

class FakeView < ActionView::Base
  # include Rails.application.routes.url_helpers
  # undef_method :fragment_name_with_digest if method_defined? :fragment_name_with_digest
  # undef_method :cache_fragment_name if method_defined? :cache_fragment_name

  with_empty_template_cache

  def compiled_method_container
    self.class
  end

  # this is a stub. Normally this would be set by the
  # controller locals

  cattr_accessor :request_forgery
  self.request_forgery = false

  def view_cache_dependencies
    []
  end

  def protect_against_forgery?
    false
  end

  def form_authenticity_token
    "secret"
  end

  def combined_fragment_cache_key(key)
    [:views, key]
  end

  def asset_pack_path(asset)
    asset
  end
end

class << Rails
  def cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

def render(source, options = {})
  @controller.cache_store = Rails.cache
  view_path = File.join(File.dirname(__FILE__), "../fixtures")
  file_resolver = ActionView::FileSystemResolver.new(view_path)
  lookup_context = ActionView::LookupContext.new([file_resolver], {}, [""])
  lookup_context.formats = [:json]
  view = FakeView.new(lookup_context, {}, @controller)
  view.assign(options.fetch(:assigns, {}))
  template = ActionView::Template.new(source, "test", Props::Handler, virtual_path: "test", locals: [])
  template.render(view, {}).strip
end

ActionView::Template.register_template_handler :props, Props::Handler

RSpec.configure do |config|
  config.before(:example) do
    @controller = ActionView::TestCase::TestController.new
    @controller.request = ActionDispatch::TestRequest.create
    @controller.response = ActionDispatch::TestResponse.new
    @controller.instance_variable_set(:@_response, @controller.response)
    @controller.cache_store = Rails.cache
    view_path = File.join(File.dirname(__FILE__), "../fixtures")
    @controller.prepend_view_path(view_path)
    @controller.formats = [:json]
  end
end
