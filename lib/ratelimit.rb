require 'redis'
require 'redis-namespace'

class Ratelimit
  COUNT_LUA_SCRIPT = <<-LUA.freeze
    local subject = KEYS[1]
    local oldest_bucket = tonumber(ARGV[1])
    local current_bucket = tonumber(ARGV[2])
    local count = 0

    for bucket = oldest_bucket + 1, current_bucket do
      local value = redis.call('HGET', subject, tostring(bucket))
      if value then
        count = count + tonumber(value)
      end
    end

    return count
  LUA

  MAINTENANCE_LUA_SCRIPT = <<-LUA.freeze
    local subject = KEYS[1]
    local oldest_bucket = tonumber(ARGV[1])

    -- Delete expired keys
    local all_keys = redis.call('HKEYS', subject)
    for _, key in ipairs(all_keys) do
      local bucket_key = tonumber(key)
      if bucket_key < oldest_bucket then
        redis.call('HDEL', subject, tostring(bucket_key))
      end
    end
  LUA

  # Create a Ratelimit object.
  #
  # @param [String] key A name to uniquely identify this rate limit. For example, 'emails'
  # @param [Hash] options Options hash
  # @option options [Integer] :bucket_span (600) Time span to track in seconds
  # @option options [Integer] :bucket_interval (5) How many seconds each bucket represents
  # @option options [Integer] :bucket_expiry (@bucket_span) How long we keep data in each bucket before it is auto expired. Cannot be larger than the bucket_span.
  # @option options [Redis]   :redis (nil) Redis client if you need to customize connection options
  #
  # @return [Ratelimit] Ratelimit instance
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
    load_scripts
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

    # Cleanup expired keys every 100th request
    cleanup_expired_keys(subject) if rand < 0.01

    redis.multi do |transaction|
      transaction.hincrby(subject, bucket, count)
      transaction.expire(subject, @bucket_expiry + @bucket_interval)
    end.first
  end

  # Returns the count for a given subject and interval
  #
  # @param [String] subject Subject for the count
  # @param [Integer] interval How far back (in seconds) to retrieve activity.
  def count(subject, interval)
    interval = [[interval, @bucket_interval].max, @bucket_span].min
    oldest_bucket = get_bucket(Time.now.to_i - interval)
    current_bucket = get_bucket
    subject = "#{@key}:#{subject}"

    execute_script(@count_script_sha, [subject], [oldest_bucket, current_bucket])
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
    (time / @bucket_interval).floor
  end

  # Cleanup expired keys for a given subject
  def cleanup_expired_keys(subject)
    oldest_bucket = get_bucket(Time.now.to_i - @bucket_expiry)
    execute_script(@maintenance_script_sha, [subject], [oldest_bucket])
  end

  # Execute the script or reload the scripts on error
  def execute_script(*args)
    redis.evalsha(*args)
  rescue Redis::CommandError => e
    raise unless e.message =~ /NOSCRIPT/

    load_scripts
    retry
  end

  # Load the lua scripts into redis
  # This must be on the redis.redis object, not the namespace
  def load_scripts
    @count_script_sha = redis.redis.script(:load, COUNT_LUA_SCRIPT)
    @maintenance_script_sha = redis.redis.script(:load, MAINTENANCE_LUA_SCRIPT)
  end

  def redis
    @redis ||= Redis::Namespace.new(:ratelimit, redis: @raw_redis || Redis.new)
  end
end
