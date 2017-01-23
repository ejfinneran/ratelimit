require 'redis'
require 'redis-namespace'

class Ratelimit

  # Create a RateLimit object.
  #
  # @param [String] key A name to uniquely identify this rate limit. For example, 'emails'
  # @param [Hash] options Options hash
  # @option options [Integer] :bucket_span (600) Time span to track in seconds
  # @option options [Integer] :bucket_interval (5) How many seconds each bucket represents
  # @option options [Integer] :bucket_expiry (@bucket_span) How long we keep data in each bucket before it is auto expired. Cannot be larger than the bucket_span.
  # @option options [Redis]   :redis (nil) Redis client if you need to customize connection options
  #
  # @return [RateLimit] RateLimit instance
  #
  def initialize(key, options = {})
    @key = key
    unless options.is_a?(Hash)
      raise ArgumentError.new("Redis object is now passed in via the options hash - options[:redis]")
    end
    @bucket_span = options[:bucket_span] || 600
    @bucket_interval = options[:bucket_interval] || 5
    @bucket_expiry = options[:bucket_expiry] || @bucket_span
    if @bucket_expiry > @bucket_span
      raise ArgumentError.new("Bucket expiry cannot be larger than the bucket span")
    end
    @bucket_count = (@bucket_span / @bucket_interval).round
    if @bucket_count < 3
      raise ArgumentError.new("Cannot have less than 3 buckets")
    end
    @raw_redis = options[:redis]
  end

  # Add to the counter for a given subject.
  #
  # @param [String]   subject A unique key to identify the subject. For example, 'user@foo.com'
  # @param [Integer]  count   The number by which to increase the counter
  #
  # @return [Integer] The counter value
  def add(subject, count = 1)
    bucket = get_bucket
    subject = "#{@key}:#{subject}"
    redis.multi do
      redis.hincrby(subject, bucket, count)
      redis.hdel(subject, (bucket + 1) % @bucket_count)
      redis.hdel(subject, (bucket + 2) % @bucket_count)
      redis.expire(subject, @bucket_expiry)
    end.first
  end

  # Returns the count for a given subject and interval
  #
  # @param [String] subject Subject for the count
  # @param [Integer] interval How far back (in seconds) to retrieve activity.
  def count(subject, interval)
    bucket = get_bucket
    interval = [interval, @bucket_interval].max
    count = (interval / @bucket_interval).floor
    subject = "#{@key}:#{subject}"

    keys = (0..count - 1).map do |i|
      (bucket - i) % @bucket_count
    end
    return redis.hmget(subject, *keys).inject(0) {|a, i| a + i.to_i}
  end

  # Check if the rate limit has been exceeded.
  #
  # @param [String] subject Subject to check
  # @param [Hash] options Options hash
  # @option options [Integer] :interval How far back to retrieve activity.
  # @option options [Integer] :threshold Maximum number of actions
  def exceeded?(subject, options = {})
    return count(subject, options[:interval]) >= options[:threshold]
  end

  # Check if the rate limit is within bounds
  #
  # @param [String] subject Subject to check
  # @param [Hash] options Options hash
  # @option options [Integer] :interval How far back to retrieve activity.
  # @option options [Integer] :threshold Maximum number of actions
  def within_bounds?(subject, options = {})
    return !exceeded?(subject, options)
  end

  # Execute a block once the rate limit is within bounds
  # *WARNING* This will block the current thread until the rate limit is within bounds.
  #
  # @param [String] subject Subject for this rate limit
  # @param [Hash] options Options hash
  # @option options [Integer] :interval How far back to retrieve activity.
  # @option options [Integer] :threshold Maximum number of actions
  # @yield The block to be run
  #
  # @example Send an email as long as we haven't send 5 in the last 10 minutes
  #   ratelimit.exec_with_threshold(email, [:threshold => 5, :interval => 600]) do
  #     send_another_email
  #     ratelimit.add(email)
  #   end
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
    @redis ||= Redis::Namespace.new(:ratelimit, redis: @raw_redis || Redis.new)
  end
end
