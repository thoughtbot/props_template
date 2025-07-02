require_relative "support/helper"

RSpec.describe "Props::Base child!" do
  context "basic functionality" do
    it "creates an array with child! blocks" do
      json = Props::Base.new
      json.array! do
        json.child! do
          json.set! :title, "hello world"
        end
      end

      attrs = json.result!.strip
      expect(attrs).to eql_json([
        { title: "hello world" }
      ])
    end

    it "creates an array with multiple child! blocks" do
      json = Props::Base.new
      json.array! do
        json.child! do
          json.set! :title, "first"
        end
        json.child! do
          json.set! :title, "second"
        end
      end

      attrs = json.result!.strip
      expect(attrs).to eql_json([
        { title: "first" },
        { title: "second" }
      ])
    end

    it "creates nested objects within child! blocks" do
      json = Props::Base.new
      json.array! do
        json.child! do
          json.set! :comment do
            json.set! :title, "wow"
          end
        end
        json.child! do
          json.set! :comment do
            json.set! :title, "noway"
          end
        end
      end

      attrs = json.result!.strip
      expect(attrs).to eql_json([
        { comment: { title: "wow" } },
        { comment: { title: "noway" } }
      ])
    end
  end
  it "allows the child to be an array" do
    json = Props::Base.new
    json.array! do
      json.child! do
        json.array! do
          json.child! do
          end
        end
      end
    end

    attrs = json.result!.strip
    expect(attrs).to eql_json([
     [{}] 
    ])
  end

  context "validation" do
    it "raises error when child! is used outside array! blocks" do
      json = Props::Base.new
      
      expect {
        json.set! :metrics do
          json.child! do
            json.set! :title, "test"
          end
        end
      }.to raise_error(Props::InvalidScopeForChildError, "child! can only be used in a `array!` with no arguments")
    end

    it "raises error when child! is used with array! that has arguments" do
      json = Props::Base.new
      
      expect {
        json.array! [1, 2] do |post|
          json.child! do
            json.set! :title, "test"
          end
        end
      }.to raise_error(Props::InvalidScopeForChildError, "child! can only be used in a `array!` with no arguments")
    end

    it "raises error when child! has no block" do
      json = Props::Base.new
      
      expect {
        json.array! do
          json.child!
        end
      }.to raise_error(ArgumentError, "child! requires a block")
    end
  end

  context "mixed with regular set!" do
    it "allows mixing array! child! with outer set!" do
      json = Props::Base.new
      json.set! :data do
        json.set! :posts do
          json.array! do
            json.child! do
              json.set! :title, "First post"
            end
            json.child! do
              json.set! :title, "Second post"
            end
          end
        end
      end

      attrs = json.result!.strip
      expect(attrs).to eql_json({
        data: {
          posts: [
            { title: "First post" },
            { title: "Second post" }
          ]
        }
      })
    end
  end

  context "empty child! blocks" do
    it "creates empty objects for empty child! blocks" do
      json = Props::Base.new
      json.array! do
        json.child! do
        end
        json.child! do
          json.set! :title, "not empty"
        end
      end

      attrs = json.result!.strip
      expect(attrs).to eql_json([
        {},
        { title: "not empty" }
      ])
    end
  end
end