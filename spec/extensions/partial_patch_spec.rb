require_relative "../support/helper"
require_relative "../support/rails_helper"
require "props_template/partial_patch"

require "action_controller"
RSpec.describe "Props::Template partial patch" do
  it "renders with a partial and layout" do
    result = @controller.render(partial: "comment", layout: "stream_message").chomp

    expect(result).to eql_json({
      greeting: "Hello world",
      data: {
        title: "some title",
        details: {
          body: "hello world"
        },
      }
    })
  end
end

