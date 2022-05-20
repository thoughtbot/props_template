require_relative '../support/helper'
require_relative '../support/rails_helper'

RSpec.describe 'Props::Template' do
  before do
    @controller.request.path = '/some_url'
  end

  it 'finds the correct node and merges it to the top' do
    json = render(<<~PROPS)
      json.data do
        json.comment do
          json.details do
            json.foo json.traveled_path!
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      data: {
        comment: {
          details: {
            foo: 'data.comment.details'
          }
        }
      },
    })
  end
end
