require 'helper'

class TestRatelimit < Test::Unit::TestCase
  def setup
    Redis.stubs(:new).returns(MockRedis.new)
    @r = Ratelimit.new("key")
    @r.send(:redis).flushdb
  end

  should "set bucket_expiry to the bucket_span if not defined" do
    @r = Ratelimit.new("key")
    assert_equal @r.instance_variable_get(:@bucket_span), @r.instance_variable_get(:@bucket_expiry)
  end

  should "not allow bucket expiry to be larger than the bucket span" do
    assert_raise(ArgumentError) do
      @r = Ratelimit.new("key", {:bucket_expiry => 1200})
    end
  end

  should "not allow redis to be passed outside of the options hash" do
    assert_raise(ArgumentError) do
      @r = Ratelimit.new("key", Redis.new)
    end
  end

  should "be able to add to the count for a given subject" do
    @r.add("value1")
    @r.add("value1")
    assert_equal 2, @r.count("value1", 1)
    assert_equal 0, @r.count("value2", 1)
    Timecop.travel(600) do
      assert_equal 0, @r.count("value1", 1)
    end
  end

  should "be able to add to the count by more than 1" do
    @r.add("value1", 3)
    assert_equal 3, @r.count("value1", 1)
  end

  should "be able to add to the count for a non-string subject" do
    @r.add(123)
    @r.add(123)
    assert_equal 2, @r.count(123, 1)
    assert_equal 0, @r.count(124, 1)
    Timecop.travel(10) do
      assert_equal 0, @r.count(123, 1)
    end
  end

  should "return counter value" do
    r = @r.add("value1")
    assert_equal @r.count("value1", 1), r
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
