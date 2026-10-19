require_relative "../support/helper"
require_relative "../support/rails_helper"
require "active_support/testing/time_helpers"
require "active_support/core_ext/string"

RSpec.describe "Props::Template caching" do
  include ActiveSupport::Testing::TimeHelpers

  before do
    Rails.cache.clear
  end

  it "caches an object" do
    json = render(<<~PROPS)
      json.author(cache: 'some_cache_key') do
        json.firstName 'hit'
      end

      json.author2(cache: 'some_cache_key') do
        json.firstName 'miss'
      end
    PROPS

    expect(json).to eql_json({
      author: {
        firstName: "hit"
      },
      author2: {
        firstName: "hit"
      }
    })
  end

  it "caches an object using an inline options object" do
    json = render(<<~PROPS)
      json.author(Props::Options.new.cache('some_cache_key')) do
        json.firstName 'hit'
      end

      json.author2(Props::Options.new.cache('some_cache_key')) do
        json.firstName 'miss'
      end
    PROPS

    expect(json).to eql_json({
      author: {
        firstName: "hit"
      },
      author2: {
        firstName: "hit"
      }
    })
  end

  it "caches an object with newlines" do
    json = render(<<~PROPS)
      json.author(cache: 'some_cache_key') do
        json.firstName "hi \nworld"
      end
    PROPS

    expect(json).to eql_json({
      author: {
        firstName: "hi \nworld"
      }
    })
  end

  it "caches an object with expiry" do
    freeze_time

    render(<<~PROPS)
      opts = {
        cache: ['some_cache_key', expires_in: 1.minute]
      }

      json.author(opts) do
        json.firstName 'hit'
      end
    PROPS

    travel 30.seconds

    json = render(<<~PROPS)
      opts = {
        cache: ['some_cache_key', expires_in: 1.minute]
      }

      json.author(opts) do
        json.firstName 'miss'
      end
    PROPS

    expect(json).to eql_json({
      author: {
        firstName: "hit"
      }
    })

    travel 31.seconds

    json = render(<<~PROPS)
      opts = {
        cache: ['some_cache_key', expires_in: 1.minute]
      }

      json.author(opts) do
        json.firstName 'miss'
      end
    PROPS

    expect(json).to eql_json({
      author: {
        firstName: "miss"
      }
    })
  end

  it "caches object in an array" do
    expect_any_instance_of(Props::Cache).to receive(:multi_fetch).and_call_original

    json = render(<<~PROPS)
      json.authors do
        opts = {
          cache: (->(i) {['some_cache', i % 2]})
        }
        json.array! [1,2,3,4], opts do |id|
          json.id id
        end
      end
    PROPS

    expect(json).to eql_json({
      authors: [
        {id: 1},
        {id: 2},
        {id: 1},
        {id: 2}
      ]
    })
  end
  it "fetches using multifetch" do
    expect_any_instance_of(Props::Cache).to receive(:multi_fetch).and_return({
      ["some_cache", 1] => "{}\n" + {id: 1}.to_json,
      ["some_cache", 2] => "{}\n" + {id: 2}.to_json,
      ["some_cache", 3] => "{}\n" + {id: 3}.to_json,
      ["some_cache", 4] => "{}\n" + {id: 4}.to_json
    })

    expect_any_instance_of(Props::Cache).to_not receive(:read_fragment_cache)

    json = render(<<~PROPS)
      json.authors do
        opts = {
          cache: (->(i) {['some_cache', i]})
        }
        json.array! [1,2,3,4], opts do |id|
          json.id id
        end
      end
    PROPS

    expect(json).to eql_json({
      authors: [
        {id: 1},
        {id: 2},
        {id: 3},
        {id: 4}
      ]
    })
  end

  it "caches object in an array with an expiry" do
    freeze_time

    render(<<~PROPS)
      json.authors do
        opts = {
          cache: [->(i) {['some_cache', i]}, expires_in: 1.minute]
        }
        json.array! [1], opts do |id|
          json.id id
        end
      end
    PROPS

    travel 30.seconds

    json = render(<<~PROPS)
      json.authors do
        opts = {
          cache: [->(i) {['some_cache', i]}, expires_in: 1.minute]
        }
        json.array! [1], opts do |id|
          json.id 'miss'
        end
      end
    PROPS

    expect(json).to eql_json({
      authors: [
        {id: 1}
      ]
    })

    travel 31.seconds

    json = render(<<~PROPS)
      json.authors do
        opts = {
          cache: [->(i) {['some_cache', i]}, expires_in: 1.minute]
        }
        json.array! [1], opts do |id|
          json.id 'miss'
        end
      end
    PROPS

    expect(json).to eql_json({
      authors: [
        {id: "miss"}
      ]
    })
  end

  it "caches a partial" do
    json = render(<<~PROPS)
      opts = {
        partial: 'simple',
        cache: 'some_cache_key'
      }

      json.author(opts) do
      end

      json.author2(opts) do
        json.first_name "this value is skipped"
      end
    PROPS

    expect(json).to eql_json({
      author: {
        foo: "bar"
      },
      author2: {
        foo: "bar"
      }
    })
  end

  it "caches partials in an array" do
    json = render(<<~PROPS)
      json.authors do
        opts = {
          cache: (->(i) {['some_cache', i % 2]}),
          partial: ['profile', as: :email]
        }

        json.array! [1,2,3,4], opts do |id|
        end
      end
    PROPS

    expect(json).to eql_json({
      authors: [
        {email: 1},
        {email: 2},
        {email: 1},
        {email: 2}
      ]
    })
  end

  it "has no effect when search is active" do
    json = render(<<~PROPS)
      json.foo(cache:'some_key') do
        json.firstName 'dave'
      end

      json.bar(cache:'some_key') do
        json.firstName 'miss'
      end

      json.author(search: ['author', 'details', 'name']) do
        json.details(cache: 'some_key') do
          json.name do
            json.firstName 'john'
          end
        end
      end
    PROPS

    expect(json).to eql_json({
      foo: {
        firstName: "dave"
      },
      bar: {
        firstName: "dave"
      },
      author: {
        firstName: "john"
      }
    })
  end

  it "is reenabled at the found subtree" do
    json = render(<<~PROPS)
      json.foo(cache:'some_key') do
        json.firstName 'dave'
      end

      json.bar(cache:'some_key') do
        json.firstName 'miss'
      end

      json.author(search: ['author']) do
        json.details(cache: 'some_key') do
          json.firstName 'john'
        end
      end
    PROPS

    expect(json).to eql_json({
      foo: {
        firstName: "dave"
      },
      bar: {
        firstName: "dave"
      },
      author: {
        details: {
          firstName: "dave"
        }
      }
    })
  end

  context "when cached in different positions" do
    it "caches the first and last object in an object" do
      json = render(<<~PROPS)
        json.author(cache: 'first_cache_key') do
          json.firstName 'hit'
        end

        json.author2(cache: 'last_cache_key') do
          json.firstName 'hit'
        end

        json.post do
          json.author(cache: 'first_cache_key') do
            json.firstName 'miss'
          end

          json.title 'live'

          json.editor(cache: 'last_cache_key') do
            json.firstName 'miss'
          end
        end
      PROPS

      expect(json).to eql_json({
        author: {
          firstName: "hit"
        },
        author2: {
          firstName: "hit"
        },
        post: {
          author: {
            firstName: "hit"
          },
          title: "live",
          editor: {
            firstName: "hit"
          }
        }
      })
    end

    it "caches consecutive objects at the start of an array" do
      json = render(<<~PROPS)
        json.authors do
          opts = {
            cache: (->(i) {['some_cache', i]})
          }
          json.array! [1,1,1,2], opts do |id|
            json.id id
          end
        end
      PROPS

      expect(json).to eql_json({
        authors: [
          {id: 1},
          {id: 1},
          {id: 1},
          {id: 2}
        ]
      })
    end

    it "caches an object holding a cached object" do
      json = render(<<~PROPS)
        json.author(cache: 'inner_cache_key') do
          json.firstName 'hit'
        end

        json.post(cache: 'outer_cache_key') do
          json.author(cache: 'inner_cache_key') do
            json.firstName 'miss'
          end

          json.title 'hit'
        end

        json.post2(cache: 'outer_cache_key') do
          json.title 'miss'
        end
      PROPS

      expect(json).to eql_json({
        author: {
          firstName: "hit"
        },
        post: {
          author: {
            firstName: "hit"
          },
          title: "hit"
        },
        post2: {
          author: {
            firstName: "hit"
          },
          title: "hit"
        }
      })
    end

    it "caches a large object" do
      json = render(<<~PROPS)
        json.author(cache: 'some_cache_key') do
          json.bio 'hit' * 30_000
        end

        json.author2(cache: 'some_cache_key') do
          json.bio 'miss'
        end
      PROPS

      expect(json).to eql_json({
        author: {
          bio: "hit" * 30_000
        },
        author2: {
          bio: "hit" * 30_000
        }
      })
    end
  end

  context "when nested" do
    before do
      @controller.request.path = "/some_url"
    end

    it "caches nested objects" do
      json = render(<<~PROPS)
        json.post(cache: 'outer_cache_key') do
          json.title 'hit'

          json.author(cache: 'inner_cache_key') do
            json.firstName 'hit'
          end

          json.body 'hit'
        end
      PROPS

      expect(json).to eql_json({
        post: {
          title: "hit",
          author: {
            firstName: "hit"
          },
          body: "hit"
        }
      })

      json = render(<<~PROPS)
        json.post(cache: 'outer_cache_key') do
          json.title 'miss'

          json.author(cache: 'inner_cache_key') do
            json.firstName 'miss'
          end

          json.body 'miss'
        end
      PROPS

      expect(json).to eql_json({
        post: {
          title: "hit",
          author: {
            firstName: "hit"
          },
          body: "hit"
        }
      })
    end

    it "caches an inner object while caching an outer object" do
      json = render(<<~PROPS)
        json.post(cache: 'outer_cache_key') do
          json.author(cache: 'inner_cache_key') do
            json.firstName 'hit'
          end
        end

        json.author2(cache: 'inner_cache_key') do
          json.firstName 'miss'
        end
      PROPS

      expect(json).to eql_json({
        post: {
          author: {
            firstName: "hit"
          }
        },
        author2: {
          firstName: "hit"
        }
      })
    end

    it "caches nested objects in an array" do
      json = render(<<~PROPS)
        json.posts do
          opts = {
            cache: (->(i) {['some_cache', i]})
          }
          json.array! [1,2,3], opts do |id|
            json.id id

            json.author(cache: "author_\#{id % 2}") do
              json.firstName "author \#{id % 2}"
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        posts: [
          {id: 1, author: {firstName: "author 1"}},
          {id: 2, author: {firstName: "author 0"}},
          {id: 3, author: {firstName: "author 1"}}
        ]
      })

      json = render(<<~PROPS)
        json.posts do
          opts = {
            cache: (->(i) {['some_cache', i]})
          }
          json.array! [1,2,3], opts do |id|
            json.id 'miss'

            json.author(cache: "author_\#{id % 2}") do
              json.firstName 'miss'
            end
          end
        end
      PROPS

      expect(json).to eql_json({
        posts: [
          {id: 1, author: {firstName: "author 1"}},
          {id: 2, author: {firstName: "author 0"}},
          {id: 3, author: {firstName: "author 1"}}
        ]
      })
    end

    it "keeps deferred and fragment paths from nested caches" do
      json = render(<<~PROPS)
        json.post(cache: 'outer_cache_key') do
          json.author(cache: 'inner_cache_key') do
            json.greeting(defer: :auto) do
              json.foo 'hello world'
            end

            json.simple(partial: ['simple', fragment: :simple]) do
            end
          end
        end

        json.deferred json.deferred!
        json.fragments json.fragments!
      PROPS

      expect(json).to eql_json({
        post: {
          author: {
            greeting: {},
            simple: {
              foo: "bar"
            }
          }
        },
        deferred: [
          {url: "/some_url?props_at=post.author.greeting", path: "post.author.greeting", type: "auto"}
        ],
        fragments: [
          {id: :simple, path: "post.author.simple"}
        ]
      })

      json = render(<<~PROPS)
        json.post(cache: 'outer_cache_key') do
          json.author(cache: 'inner_cache_key') do
            json.greeting(defer: :auto) do
              json.foo 'miss'
            end

            json.simple(partial: ['simple', fragment: :simple]) do
            end
          end
        end

        json.deferred json.deferred!
        json.fragments json.fragments!
      PROPS

      expect(json).to eql_json({
        post: {
          author: {
            greeting: {},
            simple: {
              foo: "bar"
            }
          }
        },
        deferred: [
          {url: "/some_url?props_at=post.author.greeting", path: "post.author.greeting", type: "auto"}
        ],
        fragments: [
          {id: :simple, path: "post.author.simple"}
        ]
      })
    end
  end

  context "when nested in sibling objects" do
    it "caches two objects, each with two cached objects" do
      json = render(<<~PROPS)
        json.post(cache: 'post_1') do
          json.title 'hit'

          json.author(cache: 'author_3') do
            json.firstName 'hit'
          end

          json.editor(cache: 'editor_4') do
            json.firstName 'hit'
          end
        end

        json.post2(cache: 'post_2') do
          json.title 'hit'

          json.author(cache: 'author_5') do
            json.firstName 'hit'
          end

          json.editor(cache: 'editor_6') do
            json.firstName 'hit'
          end
        end
      PROPS

      expect(json).to eql_json({
        post: {
          title: "hit",
          author: {
            firstName: "hit"
          },
          editor: {
            firstName: "hit"
          }
        },
        post2: {
          title: "hit",
          author: {
            firstName: "hit"
          },
          editor: {
            firstName: "hit"
          }
        }
      })

      json = render(<<~PROPS)
        json.post(cache: 'post_1') do
          json.title 'miss'

          json.author(cache: 'author_3') do
            json.firstName 'miss'
          end

          json.editor(cache: 'editor_4') do
            json.firstName 'miss'
          end
        end

        json.post2(cache: 'post_2') do
          json.title 'miss'

          json.author(cache: 'author_5') do
            json.firstName 'miss'
          end

          json.editor(cache: 'editor_6') do
            json.firstName 'miss'
          end
        end
      PROPS

      expect(json).to eql_json({
        post: {
          title: "hit",
          author: {
            firstName: "hit"
          },
          editor: {
            firstName: "hit"
          }
        },
        post2: {
          title: "hit",
          author: {
            firstName: "hit"
          },
          editor: {
            firstName: "hit"
          }
        }
      })
    end

    it "renders uncached objects around their cached objects" do
      render(<<~PROPS)
        json.post(cache: 'post_1') do
          json.title 'hit'

          json.author(cache: 'author_3') do
            json.firstName 'hit'
          end

          json.editor(cache: 'editor_4') do
            json.firstName 'hit'
          end
        end

        json.post2(cache: 'post_2') do
          json.title 'hit'

          json.author(cache: 'author_5') do
            json.firstName 'hit'
          end

          json.editor(cache: 'editor_6') do
            json.firstName 'hit'
          end
        end
      PROPS

      Rails.cache.delete_matched(/post_\d\z/)

      json = render(<<~PROPS)
        json.post(cache: 'post_1') do
          json.title 'miss'

          json.author(cache: 'author_3') do
            json.firstName 'miss'
          end

          json.editor(cache: 'editor_4') do
            json.firstName 'miss'
          end
        end

        json.post2(cache: 'post_2') do
          json.title 'miss'

          json.author(cache: 'author_5') do
            json.firstName 'miss'
          end

          json.editor(cache: 'editor_6') do
            json.firstName 'miss'
          end
        end
      PROPS

      expect(json).to eql_json({
        post: {
          title: "miss",
          author: {
            firstName: "hit"
          },
          editor: {
            firstName: "hit"
          }
        },
        post2: {
          title: "miss",
          author: {
            firstName: "hit"
          },
          editor: {
            firstName: "hit"
          }
        }
      })
    end
  end
end
