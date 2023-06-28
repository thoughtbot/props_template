require_relative "./support/helper"
require_relative "./support/rails_helper"
require "props_template/layout_patch"
require "action_controller"

class TestController < ActionController::Base
  protect_from_forgery

  def self.controller_path
    ""
  end
end

RSpec.describe "Props::Template" do
  it "uses a layout to render" do
    view_path = File.join(File.dirname(__FILE__), "./fixtures")
    controller = TestController.new
    controller.prepend_view_path(view_path)

    json = controller.render_to_string("200", layout: "application")

    expect(json.strip).to eql('{"data":{"success":"ok"}}')
  end

  context "when no layout exists" do
    it "skips the layout" do
      view_path = File.join(File.dirname(__FILE__), "./fixtures")
      controller = TestController.new
      controller.prepend_view_path(view_path)

      json = controller.render_to_string("200")

      expect(json.strip).to eql('{"success":"ok"}')
    end
  end
end
