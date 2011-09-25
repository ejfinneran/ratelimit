require 'helper'

class TestRatelimit < Test::Unit::TestCase
  def setup
    Redis.stubs(:new).returns(MockRedis.new)
    @r = Ratelimit.new("key")
    @r.send(:redis).flushdb
  end
  
  should "be able to add to the count for a given subject" do
    @r.add("value1")
    @r.add("value1")
    assert_equal 2, @r.count("value1", 1)
    assert_equal 0, @r.count("value2", 1)
    Timecop.travel(10) do
      assert_equal 0, @r.count("value1", 1)
    end
  end

  should "respond to exceeded? method correctly" do
    5.times do
      @r.add("value1")
    end

    assert !@r.exceeded?("value1", {:threshold => 10, :interval => 30})
    assert @r.within_bounds?("value1", {:threshold => 10, :interval => 30})

    10.times do
      @r.add("value1")
    end

    assert @r.exceeded?("value1", {:threshold => 10, :interval => 30})
    assert !@r.within_bounds?("value1", {:threshold => 10, :interval => 30})
  end

  should "accept a threshhold and a block that gets executed once it's below the threshold" do
    assert_equal 0, @r.count("key", 30)
    31.times do
      @r.add("key")
    end
    assert_equal 31, @r.count("key", 30)
    assert_raise(Timeout::Error) do
      timeout(1) do
        @r.exec_within_threshold("key", {:threshold => 30, :interval => 30}) do
          @value = 2
        end
      end
    end
    assert_nil @value
    Timecop.travel(40) do
      @r.exec_within_threshold("key", {:threshold => 30, :interval => 30}) do
        @value = 1
      end
    end
    assert_equal 1, @value
  end
end
