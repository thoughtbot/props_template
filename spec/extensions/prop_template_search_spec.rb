require_relative "../support/helper"
require_relative "../support/rails_helper"

RSpec.describe("searching the template") do
  before do
    @controller.request.path = "/some_url"
  end

  it "finds the correct node and merges it to the top" do
    json = render(<<~PROPS)
      json.data(dig: ['data', 'comment', 'details']) do
        json.comment do
          json.details do
            json.name 'john'
          end
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      data: {
        name: "john"
      },
      foo: "bar"
    })
  end
  
  it "aliases dig to search and finds the correct node and merges it to the top" do
    json = render(<<~PROPS)
      json.data(search: ['data', 'comment', 'details']) do
        json.comment do
          json.details do
            json.name 'john'
          end
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      data: {
        name: "john"
      },
      foo: "bar"
    })
  end

  it "finds an empty child node and returns an empty object" do
    json = render(<<~PROPS)
      json.data(dig: ['data', 'inner']) do
        json.inner do
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      data: {},
      foo: "bar"
    })
  end

  it "searching for a non-existant child does not set the parent, simulating undefined in JS" do
    json = render(<<~PROPS)
      json.data(dig: ['data', 'does_not_exist']) do
        json.inner do
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      foo: "bar"
    })
  end

  it "searching for nil does nothing" do
    json = render(<<~PROPS)
      json.data(dig: nil) do
        json.inner do
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      data: {
        inner: {}
      },
      foo: "bar"
    })
  end

  it "searching for an empty array means we found nothing" do
    json = render(<<~PROPS)
      json.data(dig: []) do
        json.inner do
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      foo: "bar"
    })
  end

  it "searching for a child node with siblings in back" do
    json = render(<<~PROPS)
      json.outer(dig: ['outer', 'inner']) do
        json.inner do
          json.foo 32
        end

        json.bad do
          raise 'this should not happen'
          json.foo 'should not touch'
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        foo: 32
      }
    })
  end

  it "searching for a child node with siblings in front" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner']) do
        json.bad do
          raise 'this should not happen'
          json.foo 'should not touch'
        end

        json.inner do
          json.foo 32
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        foo: 32
      }
    })
  end

  it "searches on multiple siblings" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner']) do
        json.inner do
          json.foo 32
        end
      end

      json.first(dig: ['first', 'second']) do
        json.second do
          json.bar 'cool'
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        foo: 32
      },
      first: {
        bar: "cool"
      }
    })
  end

  it "reenables search functionality at the contents of found obj nodes" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer']) do
        json.inner(dig: ['inner', 'foo']) do
          json.foo do
            json.firstName 'john'
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        inner: {
          firstName: "john"
        }
      }
    })
  end

  it "ignores search functionality in between levels of traversal" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner', 'foo']) do
        json.inner(dig: ['does_not_exist']) do
          json.foo do
            json.firstName 'john'
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        firstName: "john"
      }
    })
  end

  it "find the correct node in a partial" do
    json = render(<<~PROPS)
      json.data(dig: ['data', 'comment', 'details']) do
        json.comment(partial: 'comment') do
        end
      end
    PROPS

    expect(json).to eql_json({
      data: {
        body: "hello world"
      }
    })
  end

  it "finds a subtree" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer','inner', 'deep']) do
        json.inner do
          json.deep do
            json.deeper do
              json.foo 32
            end
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        deeper: {
          foo: 32
        }
      }
    })
  end

  it "searching for a leaf node is unsupported" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner', 'foo']) do
        json.inner do
          json.foo 32
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      foo: "bar"
    })
  end

  it "searching for a node beyond whats available is equivalent to not finding anything" do
    json = render(<<-PROPS)
      json.outer(dig: ['inner', 'a', 'b']) do
        json.inner do
          json.foo 32
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      foo: "bar"
    })
  end

  it "finds an array" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner']) do
        json.inner do
          json.array! [1, 2] do |item|
            json.foo item
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: [
        {foo: 1},
        {foo: 2}
      ]
    })
  end

  it "searching for an item inside an array" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 0]) do
        json.array! ['hello', 'world'] do |item|
          json.foo item
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        foo: "hello"
      }
    })
  end

  it "searching for an node beyond an array" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner', 1, 'foo']) do
        json.inner do
          json.array! [1, 2] do |item|
            json.foo do
              json.bar item
            end
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {
        bar: 2
      }
    })
  end

  it "searching for an node outside the length of the array, is equivalent to not finding anything" do
    json = render(<<-PROPS)
      json.outer(dig: ['inner', 10, 'foo']) do
        json.inner do
          json.array! [1, 2] do |item|
            json.foo do
              json.bar item
            end
          end
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      foo: "bar"
    })
  end

  it "searching for an node outside the length of the array, is equivalent to not finding anything" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner', 10, 'foo']) do
        json.inner do
          json.array! [1, 2] do |item|
            json.foo do
              json.bar item
            end
          end
        end
      end
      json.foo 'bar'
    PROPS

    expect(json).to eql_json({
      foo: "bar"
    })
  end

  it "searching for nested array" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer', 'inner', 1, 'foo']) do
        json.inner do
          json.array! [0, 1] do |item|
            json.foo do
              json.array! [item, 5] do |inner_item|
                json.bar inner_item
              end
            end
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: [
        {bar: 1},
        {bar: 5}
      ]
    })
  end

  it "searching for object inside a nested array" do
    json = render(<<-PROPS)
      json.outer(dig: ['outer','inner', 1, 'foo', 0]) do
        json.inner do
          json.array! [0, 1] do |item|
            json.foo do
              json.array! [item, 5] do |inner_item|
                json.bar inner_item
              end
            end
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      outer: {bar: 1}
    })
  end

  context "when searching through a partial" do
    it "returns the correct node in an object" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'comment', 'details']) do
          json.comment(partial: 'comment') do
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          body: "hello world"
        }
      })
    end

    it "ignores the fragment option" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'comment', 'details']) do
          json.comment(partial: ['comment', fragment: 'foobar']) do
          end
        end
        json.fragments json.fragments!
      PROPS

      expect(json).to eql_json({
        data: {
          body: "hello world"
        },
        fragments: []
      })
    end

    it "passes the found child obj options back to the parent" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'comment']) do
          json.comment(partial: 'comment') do
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          title: "some title",
          details: {
            body: "hello world"
          }
        }
      })
    end

    it "passes the found child obj in array options back to the parent" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'comment', 1]) do
          json.comment do
            json.array! ['hello', 'world'], {partial: ['profile', as: :email]} do
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          email: "world"
        }
      })
    end

    it "returns the correct node in an array" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'comment', 0]) do
          json.comment do
            json.array! [0], {partial: 'simple'} do
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          foo: "bar"
        }
      })
    end

    it "returns the correct node beyond an array" do
      json = render(<<~PROPS)
        json.data(dig: ['data','comment', 0, 'details']) do
          json.comment do
            json.array! [0], {partial: 'comment'} do
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          body: "hello world"
        }
      })
    end

    it "returns the correct node across nested partials" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'comment', 'details', 'contact', 'phone']) do
          json.comment(partial: 'complex') do
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          home: "111",
          cell: "222"
        }
      })
    end

    it "returns the correct node across nested partials" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'comments', 0, 0, 'details', 'contact', 'phone']) do
          opts = {
            partial: ['complex_children', locals: {children: [1,2]}]
          }

          json.comments(opts) do
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          home: "111",
          cell: "222"
        }
      })
    end
  end
end
