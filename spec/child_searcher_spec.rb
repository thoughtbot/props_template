require_relative "support/helper"
require_relative "support/rails_helper"

RSpec.describe "Props::Template child! with searcher" do
  before do
    @controller.request.path = "/some_url"
  end

  context "dig functionality with child!" do
    it "finds specific child by index using dig" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'posts', '1', 'comment']) do
          json.posts do
            json.array! do
              json.child! do
                json.comment do
                  json.title "wow"
                end
              end
              json.child! do
                json.comment do
                  json.title "noway"
                end
              end
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          title: "noway"
        }
      })
    end

    it "finds first child when index is 0" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'posts', '0', 'comment']) do
          json.posts do
            json.array! do
              json.child! do
                json.comment do
                  json.title "first"
                end
              end
              json.child! do
                json.comment do
                  json.title "second"
                end
              end
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          title: "first"
        }
      })
    end

    it "works with deeper nested paths" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'content', '1', 'nested', '0']) do
          json.content do
            json.array! do
              json.child! do
                json.nested do
                  json.array! do
                    json.content do
                      json.value "skip this"
                    end
                  end
                end
              end
              json.child! do
                json.nested do
                  json.array! do
                    json.child! do
                      json.value "found it"
                    end
                  end
                end
              end
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {value: "found it"}
      })
    end

    it "returns nothing when child index doesn't exist" do
      json = render(<<~PROPS)
        json.data(dig: ['data', 'posts', '5']) do
          json.posts do
            json.array! do
              json.child! do
                json.title "only child"
              end
            end
          end
        end
      PROPS

      expect(json).to eql_json({})
    end
  end

  context "search functionality with child!" do
    it "finds child using search parameter" do
      json = render(<<~PROPS)
        json.data(search: ['data', 'items', '0']) do
          json.items do
            json.array! do
              json.child! do
                json.name "target item"
              end
              json.child! do
                json.name "other item"
              end
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        data: {
          name: "target item"
        }
      })
    end
  end
end