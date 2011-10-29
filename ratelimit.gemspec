Gem::Specification.new do |s|
  s.name        = 'ratelimit'
  s.version     = '0.0.1'
  s.date        = '2011-10-29'
  s.summary     = "Rate limiting backed by redis"
  s.description = "This library uses Redis to track the number of actions for a given subject over a flexible time frame."
  s.authors     = ["E.J. Finneran"]
  s.email       = ["ej.finneran@gmail.com"]
  s.homepage    = "http://github.com/ejfinneran/ratelimit"
  s.files       = ["lib/ratelimit.rb"]
  s.add_dependency  "redis", ">= 2.0.0"
  s.add_dependency  "redis-namespace", ">= 1.0.0"
end
