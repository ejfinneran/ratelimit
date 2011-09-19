require 'helper'

class TestRatelimit < Test::Unit::TestCase
  def setup
    @r = Ratelimit.new("key", 10, 1, 100) 
    @r.redis.flushdb
  end
  
  should "be able to add to the count for a given subject" do
    @r.add("value1")
    @r.add("value1")
    assert_equal 2, @r.count("value1", 1)
    assert_equal 0, @r.count("value2", 1)
    sleep 2
    assert_equal 0, @r.count("value1", 1)
  end
end
