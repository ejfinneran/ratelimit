require 'coveralls'
Coveralls.wear!
require 'rubygems'
require 'bundler'
require 'redis'
require 'mock_redis'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'timecop'
require 'timeout'
# Mock out redis for tests
#Redis.stubs(:new).returns(MockRedis.new)

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'ratelimit'

class Test::Unit::TestCase
end
