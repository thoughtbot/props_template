$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "active_support"
require 'action_view'
require 'action_view/testing/resolvers'


class FakeController
  def perform_caching
    true
  end

  def instrument_fragment_cache(a, b)
    yield
  end

  def cache
    Rails.cache
  end
end

class FakeContext
  attr_reader :controller

  def cache_fragment_name(key, options = nil)
    key
  end

  def initialize
    @controller = FakeController.new
  end
end
