require 'spec_helper'

describe Ratelimit do
  describe '.initialize' do
    subject { described_class.new(key, options) }

    let(:options) { Hash.new }

    context 'with key' do
      let(:key) { 'key' }

      context 'with redis option' do
        let(:redis) { double('redis') }
        let(:options) { super().merge(redis: redis) }

        it 'wraps redis in redis-namespace' do
          expect(subject.send(:redis)).to be_instance_of(Redis::Namespace)
        end
      end
    end
  end

  before do
    @r = Ratelimit.new("key")
    @r.send(:redis).flushdb
  end

  it "should set_bucket_expiry to the bucket_span if not defined" do
    expect(@r.instance_variable_get(:@bucket_span)).to eq(@r.instance_variable_get(:@bucket_expiry))
  end

  it "should not allow bucket count less than 3" do
    expect do
      Ratelimit.new("key", {:bucket_span => 1, :bucket_interval => 1})
    end.to raise_error(ArgumentError)
  end

  it "should not allow bucket expiry to be larger than the bucket span" do
    expect do
      Ratelimit.new("key", {:bucket_expiry => 1200})
    end.to raise_error(ArgumentError)
  end

  it "should not allow redis to be passed outside of the options hash" do
    expect do
      Ratelimit.new("key", Redis.new)
    end.to raise_error(ArgumentError)
  end

  it "should be able to add to the count for a given subject" do
    @r.add("value1")
    @r.add("value1")
    expect(@r.count("value1", 1)).to eq(2)
    expect(@r.count("value2", 1)).to eq(0)
    Timecop.travel(600) do
      expect(@r.count("value1", 1)).to eq(0)
    end
  end

  it "should be able to add to the count by more than 1" do
    @r.add("value1", 3)
    expect(@r.count("value1", 1)).to eq(3)
  end

  it "should be able to add to the count for a non-string subject" do
    @r.add(123)
    @r.add(123)
    expect(@r.count(123, 1)).to eq(2)
    expect(@r.count(124, 1)).to eq(0)
    Timecop.travel(10) do
      expect(@r.count(123, 1)).to eq(0)
    end
  end

  it "should return counter value" do
    counter_value = @r.add("value1")
    expect(@r.count("value1", 1)).to eq(counter_value)
  end

  it "respond to exceeded? method correctly" do
    5.times do
      @r.add("value1")
    end

    expect(@r.exceeded?("value1", {:threshold => 10, :interval => 30})).to be false
    expect(@r.within_bounds?("value1", {:threshold => 10, :interval => 30})).to be true

    10.times do
      @r.add("value1")
    end

    expect(@r.exceeded?("value1", {:threshold => 10, :interval => 30})).to be true
    expect(@r.within_bounds?("value1", {:threshold => 10, :interval => 30})).to be false
  end

  it "accept a threshold and a block that gets executed once it's below the threshold" do
    expect(@r.count("key", 30)).to eq(0)
    31.times do
      @r.add("key")
    end
    expect(@r.count("key", 30)).to eq(31)

    @value = nil
    expect do
      timeout(1) do
        @r.exec_within_threshold("key", {:threshold => 30, :interval => 30}) do
          @value = 2
        end
      end
    end.to raise_error(Timeout::Error)
    expect(@value).to be nil
    Timecop.travel(40) do
      @r.exec_within_threshold("key", {:threshold => 30, :interval => 30}) do
        @value = 1
      end
    end
    expect(@value).to be 1
  end


  it "counts correctly if bucket_span equals count-interval  " do
    @r = Ratelimit.new("key", {:bucket_span => 10, bucket_interval: 1})
    @r.add('value1')
    expect(@r.count('value1', 10)).to eql(1)
  end

  it "counts correctly if interval is greater than bucket_span" do
    @r = Ratelimit.new("key", { bucket_span: 10, bucket_interval: 1})
    @r.add('value1')
    expect(@r.count('value1', 40)).to eql(1)
  end
end
