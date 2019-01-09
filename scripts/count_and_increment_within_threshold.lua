local subject = KEYS[1];
local numKeys = tonumber(ARGV[1]);
local numBurstKeys = tonumber(ARGV[numKeys + 2]);
local totalKeys = numKeys + numBurstKeys;
local bucket = tonumber(ARGV[totalKeys + 3]);
local bucketCount = tonumber(ARGV[totalKeys + 4]);
local bucketExpiry = tonumber(ARGV[totalKeys + 5]);
local threshold = tonumber(ARGV[totalKeys + 6]);
local increment = tonumber(ARGV[totalKeys + 7]);
local burstThreshold = tonumber(ARGV[totalKeys + 8]) or 0;
local success = false;
local withinBurstThreshold = false;
local withinRegularThreshold = false;
local burstCount = 0;

if numBurstKeys > 0 then
  local burstCounts = redis.call("HMGET", subject, unpack(ARGV, numKeys + 3,  totalKeys + 2 ));
  for key, value in ipairs(burstCounts) do 
    burstCount = burstCount + (tonumber(value) or 0) 
  end;

  if burstCount < burstThreshold then
    withinBurstThreshold = true;
  end
end

local count = 0;
local counts = redis.call("HMGET", subject, unpack(ARGV, 2, numKeys + 1));
for key, value in ipairs(counts) do 
  count = count + (tonumber(value) or 0) 
end;

if count < threshold then
  withinRegularThreshold = true;
end

if withinRegularThreshold or withinBurstThreshold then
  redis.call("HINCRBY", subject, bucket, increment);
  redis.call("HDEL", subject, (bucket + 1) % bucketCount);
  redis.call("HDEL", subject, (bucket + 2) % bucketCount);
  redis.call("EXPIRE", subject, bucketExpiry);
  success = true;
end

return success;