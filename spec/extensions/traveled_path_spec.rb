require_relative "../support/helper"
require_relative "../support/rails_helper"

RSpec.describe "Props::Template" do
  before do
    @controller.request.path = "/some_url"
  end

  it "returns the path of the node its called from" do
    json = render(<<~PROPS)
      json.data do
        json.comment do
          json.full_details do
            json.foo json.traveled_path!
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      data: {
        comment: {
          fullDetails: {
            foo: "data.comment.full_details"
          }
        }
      }
    })
  end
end
