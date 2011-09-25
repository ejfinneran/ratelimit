require 'redis'
require 'redis-namespace'

class Ratelimit

  attr_reader :bucket_interval

  def initialize(key, bucket_span = 600, bucket_interval = 5, bucket_expiry = 1200, redis = nil)
    @key = key
    @bucket_span = bucket_span
    @bucket_interval = bucket_interval
    @bucket_expiry = bucket_expiry
    @bucket_count = (@bucket_span / @bucket_interval).round
    @redis = redis
  end

  def add(subject)
    bucket = get_bucket
    subject = @key + ":" + subject
    redis.multi do
      redis.hincrby(subject, bucket, 1)
      redis.hdel(subject, (bucket + 1) % @bucket_count)
      redis.hdel(subject, (bucket + 2) % @bucket_count)
      redis.expire(subject, @bucket_expiry)
    end 
  end

  def count(subject, interval)
    bucket = get_bucket
    interval = [interval, @bucket_interval].max
    count = (interval / @bucket_interval).floor
    subject = @key + ":" + subject
    counts = redis.multi do
      redis.hget(subject, bucket)
      count.downto(1) do
        bucket -= 1
        redis.hget(subject, (bucket + @bucket_count) % @bucket_count)
      end
    end
    return counts.inject(0) {|a, i| a += i.to_i}
  end

  def exceeded?(subject, options = {})
    return count(subject, options[:interval]) >= options[:threshold]
  end

  def within_bounds?(subject, options = {})
    return !exceeded?(subject, options)
  end

  def exec_within_threshold(subject, options = {}, &block)
    options[:threshold] ||= 30
    options[:interval] ||= 30
    while exceeded?(subject, options)
      sleep @bucket_interval
    end
    yield(self)
  end

  private

  def get_bucket(time = Time.now.to_i)
    ((time % @bucket_span) / @bucket_interval).floor
  end

  def redis
    @@redis = Redis::Namespace.new(:ratelimit, :redis => @redis || Redis.new)
  end
end
