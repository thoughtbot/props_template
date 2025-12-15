require_relative "support/helper"
require_relative "support/rails_helper"

RSpec.describe "Props::Helper" do
  it "returns Props::Options instance" do
    json = render(<<~PROPS)
      opts = props_options
      json.is_a_props_options opts.is_a? Props::Options
    PROPS

    expect(json).to eql_json({is_a_props_options: true})
  end
end
