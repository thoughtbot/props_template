require_relative "../support/helper"
require_relative "../support/rails_helper"

RSpec.describe "Props::Template key extension" do
  it "renders an array of items with id using :key as the method_name" do
    json = render(<<~PROPS)
      klass = Struct.new(:email, :id)

      users = [
        klass.new('joe@red.com', 1),
        klass.new('foo@red.com', 2)
      ]

      json.data do
        json.array! users, key: :id do |person|
          json.email person.email
        end
      end
    PROPS

    expect(json).to eql_json({
      data: [
        {
          email: "joe@red.com",
          id: 1
        },
        {
          email: "foo@red.com",
          id: 2
        }
      ]
    })
  end

  it "renders an array of items with id using :key as the method_name via an options object" do
    json = render(<<~PROPS)
      klass = Struct.new(:email, :id)

      users = [
        klass.new('joe@red.com', 1),
        klass.new('foo@red.com', 2)
      ]

      json.data do
        json.array! users, Props::Options.new.id_key(:id) do |person|
          json.email person.email
        end
      end
    PROPS

    expect(json).to eql_json({
      data: [
        {
          email: "joe@red.com",
          id: 1
        },
        {
          email: "foo@red.com",
          id: 2
        }
      ]
    })
  end

  it "preserves the id option when digging is exact" do
    json = render(<<~PROPS)
      klass = Struct.new(:email, :id)

      users = [
        klass.new('joe@red.com', 1),
        klass.new('foo@red.com', 2)
      ]

      json.data(dig: ['data', 0]) do
        json.array! users, key: :id do |person|
          json.email person.email
        end
      end
    PROPS

    expect(json).to eql_json({
      data: {
        email: "joe@red.com",
        id: 1
      }
    })
  end
end
