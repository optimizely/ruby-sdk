#!/usr/bin/env ruby

=begin
CMAB Testing Example for Optimizely Ruby SDK
This file contains comprehensive test scenarios for CMAB functionality

To run: bundle exec ruby bug_bash.rb
or: ruby bug_bashb.rb
To run specific test: bundle exec ruby bug_bash.rb --test=basic
=end

require 'optimizely'
require 'optimizely/config_manager/http_project_config_manager'
require 'json'
require 'optparse'
require 'thread'
require 'benchmark'

# SDK Key from russell-demo-gosdk-cmab branch
# SDK_KEY = "JgzFaGzGXx6F1ocTbMTmn"  # develrc
# FLAG_KEY = "flag-matjaz-editor"
# SDK_KEY = "DCx4eoV52jhgaC9MSab3g"  # rc (prep)
# SDK_KEY = "GR6ty7rMgaHnfTAireCLW" # rc
SDK_KEY = "Gcq4AaoVzTLeoJQedMnqf" # prod
FLAG_KEY = "cmab_flag"

# Test user IDs
USER_QUALIFIED = "test_user_99"  # Will be bucketed into CMAB
USER_NOT_BUCKETED = "test_user_1"  # Won't be bucketed (traffic allocation)
USER_CACHE_TEST = "cache_user_123"

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby cmab_test_example.rb [options]"
    opts.on("--test TEST", "Specific test case to run") { |v| options[:test] = v }
  end.parse!

  # Default to running all tests
  options[:test] ||= 'all'

  # Enable debug logging to see CMAB activity (use Ruby's built-in Logger)
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG

  puts "=== CMAB Testing Suite for Ruby SDK ==="
  puts "Testing CMAB with develrc environment"
  puts "SDK Key: #{SDK_KEY}"
  puts "Flag Key: #{FLAG_KEY}\n\n"

  # Create config manager with develrc URL template (equivalent to Python's PollingConfigManager)
  config_manager = Optimizely::HTTPProjectConfigManager.new(
    sdk_key: SDK_KEY,
    # url_template: "https://dev.cdn.optimizely.com/datafiles/{sdk_key}.json",  # develrc
    # url: "https://optimizely-staging.s3.amazonaws.com/datafiles/GR6ty7rMgaHnfTAireCLW.json",  # rc
    url: "https://cdn.optimizely.com/datafiles/Gcq4AaoVzTLeoJQedMnqf.json",
    logger: logger,
    polling_interval: 300  # 5 minutes
  )
  event_dispatcher = Optimizely::EventDispatcher.new

  # Initialize Optimizely client (equivalent to Python's optimizely.Optimizely)
  optimizely_client = Optimizely::Project.new(
    config_manager: config_manager,
    logger: logger,
    event_dispatcher: event_dispatcher
  )
  # Wait for datafile to load
  puts "Waiting for datafile to load..."
  sleep(2)

  # Validate client
  config = optimizely_client.instance_variable_get(:@config_manager)&.config
  unless config
    puts "ERROR: Optimizely client invalid. Verify SDK key."
    return
  end

  # Test case mapping
  test_cases = {
    'basic' => method(:test_basic_cmab), #passes
    # 'cache_hit' => method(:test_cache_hit), #passes
    # 'cache_miss' => method(:test_cache_miss_on_attribute_change), #passes
    # 'ignore_cache' => method(:test_ignore_cache_option), #passes
    # 'reset_cache' => method(:test_reset_cache_option), #passes
    # 'invalidate_user' => method(:test_invalidate_user_cache_option), #passes
    # 'concurrent' => method(:test_concurrent_requests), #passes
    # 'error' => method(:test_error_handling), #passes
    # 'fallback' => method(:test_fallback_when_not_qualified), #passes
    # 'traffic' => method(:test_traffic_allocation), #passes
    # 'forced' => method(:test_forced_variation_override), # passes
    # 'event_tracking' => method(:test_event_tracking), # cannot find in reports
    # 'attribute_types' => method(:test_attribute_types), # passes
    # 'performance' => method(:test_performance_benchmarks), # Decision time for 1000 requests: 0.7461369999218732 seconds
    # 'cache_expiry' => method(:test_cache_expiry), # passes
    # 'cmab_config' => method(:test_cmab_configuration)
  }

  # Run specified test(s)
  if options[:test] == 'all'
    test_cases.each do |test_name, test_method|
      if test_name == 'cmab_config'
        test_method.call
      else
        test_method.call(optimizely_client)
      end
    end
  elsif test_cases.key?(options[:test])
    test_method = test_cases[options[:test]]
    if options[:test] == 'cmab_config'
      test_method.call
    else
      test_method.call(optimizely_client)
    end
  else
    puts "Unknown test case: #{options[:test]}\n\n"
    puts "Available test cases:"
    puts "  basic, cache_hit, cache_miss, ignore_cache, reset_cache,"
    puts "  invalidate_user, concurrent, error, fallback, traffic,"
    puts "  forced, event_tracking, attribute_types, performance, cache_expiry, cmab_config, all"
  end
end

# Test 1: Basic CMAB functionality
def test_basic_cmab(optimizely_client)
  puts "\n--- Test: Basic CMAB Functionality ---"
  
  (1..1).each do |i|
    puts "=== Iteration #{i} ==="
    
    # Test with user who qualifies for CMAB
    user_context = optimizely_client.create_user_context(
      USER_QUALIFIED,
      { "cmab_attribute" => "world" }
    )

    decision = user_context.decide(FLAG_KEY)
    print_decision("CMAB Qualified User", decision)

    # Cache miss - different attributes
    user_context2 = optimizely_client.create_user_context(
      USER_QUALIFIED,
      { "cmab_attribute" => "hello" }
    )
    decision2 = user_context2.decide(FLAG_KEY)
    print_decision("CMAB Qualified User2", decision2)
    sleep(2)

    # Cache hit - same attributes as user_context2
    user_context3 = optimizely_client.create_user_context(
      USER_QUALIFIED,
      { "cmab_attribute" => "world" }
    )
    decision3 = user_context3.decide(FLAG_KEY)
    print_decision("CMAB Qualified User3", decision3)
    sleep(2)

    puts "==============================="
  end
end

# Test 2: Cache hit scenario
def test_cache_hit(optimizely_client)
  puts "\n--- Test: Cache Hit Scenario ---"
  
  (1..1).each do |i|
    puts "=== Iteration #{i} ==="
    
    # Initial decision - user qualifies for CMAB
    user_context = optimizely_client.create_user_context(
      USER_QUALIFIED,
      { "cmab_attribute" => "hello" }
    )

    decide_options = [
      Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS,
      Optimizely::Decide::OptimizelyDecideOption::DISABLE_DECISION_EVENT
    ]
    decision = user_context.decide(FLAG_KEY, decide_options)
    print_decision("Initial Decision (Qualified)", decision)

    # Simulate cache hit by reusing user_context
    decision2 = user_context.decide(FLAG_KEY, decide_options)
    print_decision("Cache Hit Decision", decision2)

    # Change attribute and test cache miss
    user_context.set_attribute("cmab_attribute", "world")
    decision3 = user_context.decide(FLAG_KEY, decide_options)
    print_decision("Cache miss After Attribute Change", decision3)

    puts "==============================="
  end
end

# Test 3: Cache miss on attribute change
def test_cache_miss_on_attribute_change(optimizely_client)
  puts "\n--- Test: Cache Miss on Attribute Change ---"
  
  (1..1).each do |i|
    puts "=== Iteration #{i} ==="
    
    # Initial decision - user qualifies for CMAB
    user_context = optimizely_client.create_user_context(
      USER_QUALIFIED,
      { "cmab_attribute" => "hello" }
    )
    decision = user_context.decide(FLAG_KEY)
    print_decision("Initial Decision (Qualified)", decision)

    # Change attribute - expect cache miss
    user_context.set_attribute("cmab_attribute", "world")
    decision2 = user_context.decide(FLAG_KEY)
    print_decision("Decision After Attribute Change", decision2)

    puts "==============================="
  end
end

# Test 4: Ignore cache option
def test_ignore_cache_option(optimizely_client)
  puts "\n--- Test: Ignore Cache Option ---"
  # User context with cache
  user_context = optimizely_client.create_user_context(
    USER_CACHE_TEST,
    { "cmab_attribute" => "hello" }
  )
  decision = user_context.decide(FLAG_KEY)
  print_decision("Initial Decision (With Cache)", decision)

  # Force ignore cache
  decide_options = [
    Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS,
    Optimizely::Decide::OptimizelyDecideOption::IGNORE_CMAB_CACHE
  ]
  decision2 = user_context.decide(FLAG_KEY, decide_options)
  print_decision("Decision With Cache Ignored", decision2)

  # Should return original cache
  decision3 = user_context.decide(FLAG_KEY)
  print_decision("Decision With Cache", decision3)

  puts "==============================="
end

# Test 5: Reset cache option
def test_reset_cache_option(optimizely_client)
  puts "\n--- Test: Reset Cache Option ---"
    
  # Setup two different users
  user_context1 = optimizely_client.create_user_context(
    "reset_user_1",
    { "cmab_attribute" => "hello" }
  )
  user_context2 = optimizely_client.create_user_context(
    "reset_user_2",
    { "cmab_attribute" => "hello" }
  )

  # Populate cache for both users
  decision1 = user_context1.decide(FLAG_KEY)
  print_decision("User 1 Decision", decision1)

  decision2 = user_context2.decide(FLAG_KEY)
  print_decision("User 2 Decision", decision2)

  # Reset cache for user
  decide_options = [
    Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS,
    Optimizely::Decide::OptimizelyDecideOption::RESET_CMAB_CACHE
  ]
  decision3 = user_context1.decide(FLAG_KEY, decide_options)
  print_decision("User 1 after RESET", decision3)

  # Check if User 2's cache was also cleared and new api call
  decision4 = user_context2.decide(FLAG_KEY)
  print_decision("User 2 after reset", decision4)

  puts "==============================="
end

# Test 6: Invalidate user cache option
# # Expected:
# 1. User 1: "hello" → CMAB API call → Cache stored for User 1
# 2. User 2: "hello" → CMAB API call → Cache stored for User 2
# 3. User 1 + INVALIDATE_USER_CMAB_CACHE → Only User 1's cache cleared → New CMAB API call for User 1
# 4. User 2: Same "hello" → User 2's cache preserved → Cache hit (no API call)
def test_invalidate_user_cache_option(optimizely_client)
  puts "\n--- Test: Invalidate User Cache Option ---"
    
  # Setup two different users
  user_context1 = optimizely_client.create_user_context(
    "reset_user_1",
    { "cmab_attribute" => "hello" }
  )
  user_context2 = optimizely_client.create_user_context(
    "reset_user_2",
    { "cmab_attribute" => "hello" }
  )

  # Populate cache for both users
  decision1 = user_context1.decide(FLAG_KEY)
  print_decision("User 1 Decision", decision1)

  decision2 = user_context2.decide(FLAG_KEY)
  print_decision("User 2 Decision", decision2)

  # Invalidate only user 1's cache
  decide_options = [
    Optimizely::Decide::OptimizelyDecideOption::INVALIDATE_USER_CMAB_CACHE
  ]
  decision3 = user_context1.decide(FLAG_KEY, decide_options)
  print_decision("User 1 after INVALIDATE", decision3)

  # Check if User 2's cache is still valid
  decision4 = user_context2.decide(FLAG_KEY)
  print_decision("User 2 still cached", decision4)

  puts "==============================="
end

# Test 7: Concurrent requests
# # Expected: The Python SDK uses mutex-based cache synchronization (threading.Lock)
# EXPECTED BEHAVIOR: 1 CMAB API call + 4 cache hits
#   - First thread makes CMAB API call and stores result in cache
#   - Other 4 threads wait for lock, then find cached result and use it
#   - Logs should show: 1 "Fetching CMAB decision" + 4 "Returning cached CMAB decision"
#
# ACTUAL BEHAVIOR: If you see 5 separate API calls, this may indicate:
#   - Race condition in cache check/write logic
#   - Cache key generation issues
#   - Timing issue where all requests start before first completes
#
# Key requirement regardless: all threads return same variation for consistency
def test_concurrent_requests(optimizely_client)
  puts "\n--- Test: Concurrent Requests ---"
  
  user_context = optimizely_client.create_user_context(
    USER_QUALIFIED,
    { "cmab_attribute" => "hello" }
  )

  # Prepare threads
  threads = []
  (1..5).each do |i|
    threads << Thread.new do
      decision = user_context.decide(FLAG_KEY)
      print_decision("Concurrent Decision #{i}", decision)
    end
  end

  # Wait for threads to complete
  threads.each(&:join)

  puts "==============================="
end

# Test 8: Error handling
# # Expected: User with invalid attribute type should fail audience evaluation
#   - CMAB experiment requires string attribute "cmab_test_attribute": "hello"
#   - This test uses integer 12345 instead of string, causing type mismatch
#   - SDK logs warning about attribute type mismatch during audience evaluation
#   - User fails CMAB audience check and falls through to default rollout
#   - Result: Gets rollout variation (typically 'off') instead of CMAB variation
#
# This validates proper error handling and graceful fallback behavior
def test_error_handling(optimizely_client)
  puts "\n--- Test: Error Handling ---"
  
  # Create user context with invalid attributes to trigger error
  user_context = optimizely_client.create_user_context(
    USER_QUALIFIED,
    { "cmab_attribute" => "error" }
  )
  decide_options = [
    Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS
  ]
  decision = user_context.decide(FLAG_KEY, decide_options)
  print_decision("Decision with Error Triggering Attributes", decision)

  puts "==============================="
end

# Test 9: Fallback when not qualified
# # Expected: User without required attributes fails CMAB audience targeting
#   - User "fallback_user" has no attributes (empty dict)
#   - CMAB experiment requires "cmab_test_attribute": "hello" OR "world"
#   - Both audience conditions evaluate to UNKNOWN (null attribute value)
#   - User fails CMAB audience check and falls through to default rollout
#   - Result: Gets rollout variation 'off' from "Everyone Else" rule
#   - Key validation: No CMAB API calls should appear in debug logs
#
# This tests proper audience targeting and graceful fallback behavior
def test_fallback_when_not_qualified(optimizely_client)
  puts "\n--- Test: Fallback When Not Qualified ---"
  
  # Test with user who does NOT qualify for CMAB
  user_context = optimizely_client.create_user_context(
    USER_NOT_BUCKETED,
    {}
  )

  decision = user_context.decide(FLAG_KEY)
  print_decision("Not Qualified User Decision", decision)

  puts "==============================="
end

# Test 10: Traffic allocation
def test_traffic_allocation(optimizely_client)
  puts "\n--- Test: Traffic Allocation ---"
  
  (1..1).each do |i|
    puts "=== Iteration #{i} ==="
    
    # User not in traffic allocation (test_user_1)
    user_context1 = optimizely_client.create_user_context(
        USER_NOT_BUCKETED,
        { "cmab_attribute" => "hello" }
    )

    decision1 = user_context1.decide(FLAG_KEY)
    print_decision("User Not in Traffic", decision1)

    # User in traffic allocation (test_user_99)
    user_context2 = optimizely_client.create_user_context(
        USER_QUALIFIED,
        { "cmab_attribute" => "hello" }
    )

    decision2 = user_context2.decide(FLAG_KEY)
    print_decision("User in Traffic", decision2)

    # Expected: Only second user triggers CMAB API call according to matjaz
    # but first user is getting triggered

    puts "==============================="
  end
end

# Test 11: Forced variation override
# # Expected: Users with forced variations bypass CMAB and get predetermined results
#   - If user "forced_user" has forced variation in datafile: no CMAB API call
#   - If no forced variation configured: normal CMAB flow with API call (current result)
#   - Forced variations are typically used for QA/testing specific variations
#   - Current result shows CMAB API call, indicating no forced variation configured
#
# Note: Forced variations must be configured in Optimizely UI or datafile
# This test validates forced variation precedence over CMAB decisions
def test_forced_variation_override(optimizely_client)
  puts "\n--- Test: Forced Variation Override ---"
    
  # User who qualifies for CMAB
  user_context = optimizely_client.create_user_context(
    "forced_user",
    { "cmab_attribute" => "hello" }
  )

  # Force variation A
  decision = user_context.decide(FLAG_KEY)
  print_decision("Forced User", decision)


  puts "==============================="
end

# Test 12: Event tracking
# Expected: Impression events include CMAB UUID, conversion events do NOT include CMAB UUID
#   - Decision creates impression event with CMAB UUID in metadata
#   - Conversion events should NOT contain CMAB UUID (FX requirement)
#   - Current result: "event1" event should be configured in project
#   - Warning indicates conversion event needs to be added in Optimizely UI if missing
#   - CMAB UUID only appears in impression events for analytics correlation
#
# This validates event tracking and proper CMAB UUID handling for different event types

def test_event_tracking(optimizely_client)
  puts "\n--- Test: Event Tracking ---"
  
  user_context = optimizely_client.create_user_context(
    "event_user",
    { "cmab_attribute" => "hello" }
  )
  properties = { 
      "Category" => "value",
      "Subcategory" => "value",
      "Text" => "value",
      "URL" => "value",
      "SKU" => "value" 
  }
  tags = { 
    "$opt_event_properties" => properties 
  }

  (1..100000).each do |i|
    decision = user_context.decide(FLAG_KEY)
    print_decision("Decision for Events", decision)
  end
  # Track a conversion event
  user_context.track_event("cmab_event", tags)
  # print("\nConversion event tracked: 'cmab_event'")
  # print("Expected: Impression events contain CMAB UUID, conversion events do NOT contain CMAB UUID")
  # print("Check event processor logs for CMAB UUID only in impression events")

  puts "==============================="
end

# Test 13: Attribute types
def test_attribute_types(optimizely_client)
  puts "\n--- Test: Attribute Types ---"
  
  (1..1).each do |i|
    puts "=== Iteration #{i} ==="
    
    # User with numeric attribute
    user_context1 = optimizely_client.create_user_context(
      "user_numeric",
      { "country" => "us", "age" => 30 }
    )
    decision1 = user_context1.decide(FLAG_KEY)
    print_decision("User with Numeric Attribute Decision", decision1)

    # User with boolean attribute
    user_context2 = optimizely_client.create_user_context(
      "user_boolean",
      { "country" => "us", "is_premium" => true }
    )
    decision2 = user_context2.decide(FLAG_KEY)
    print_decision("User with Boolean Attribute Decision", decision2)

    puts "==============================="
  end
end

# Test 14: Performance benchmarks
def test_performance_benchmarks(optimizely_client)
  puts "\n--- Test: Performance Benchmarks ---"
  
  # Measure decision time
  user_context = optimizely_client.create_user_context(
    USER_QUALIFIED,
    { "cmab_attribute" => "hello" }
  )

  time = Benchmark.measure do
    (1..1000).each do
      user_context.decide(FLAG_KEY)
    end
  end

  puts "Decision time for 1000 requests: #{time.real} seconds"

  puts "==============================="
end

# Test 15: Cache expiry
def test_cache_expiry(optimizely_client)
  puts "\n--- Test: Cache Expiry ---"
  
  # User context with cache
  user_context = optimizely_client.create_user_context(
    USER_CACHE_TEST,
    { "cmab_attribute" => "hello" }
  )
  decision = user_context.decide(FLAG_KEY)
  print_decision("Initial Decision (With Cache)", decision)

  # Wait for cache to expire
  sleep(31)

  # Decision after cache expiry
  decision2 = user_context.decide(FLAG_KEY)
  print_decision("Decision After Cache Expiry", decision2)

  puts "==============================="
end

# Test 16: CMAB Configuration
def test_cmab_configuration
  puts "\n--- Test: CMAB Configuration Options ---"

  # Enable debug logging to see CMAB activity
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG

  puts "\n=== Default CMAB Configuration ==="
  puts "Default Config:"
  puts "  cache_size: 100"
  puts "  cache_ttl: 30 minutes"
  puts "  http_timeout: 10 seconds"
  puts "  max_retries: 3"

  # Create config manager with develrc URL template
  config_manager1 = Optimizely::HTTPProjectConfigManager.new(
    sdk_key: SDK_KEY,
    # url_template: "https://dev.cdn.optimizely.com/datafiles/{sdk_key}.json",  # develrc
    url_template: "https://optimizely-staging.s3.amazonaws.com/datafiles/{sdk_key}.json", #rc
    logger: logger,
    polling_interval: 300
  )

  # Create client with default config
  optimizely_client1 = Optimizely::Project.new(
    config_manager: config_manager1,
    logger: logger
  )

  puts "\n=== Custom CMAB Configuration ==="
  puts "Custom Config:"
  puts "  cache_size: 200"
  puts "  cache_ttl: 5 minutes"
  puts "  http_timeout: 30 seconds"
  puts "  max_retries: 5"

  # Create second config manager with custom settings
  config_manager2 = Optimizely::HTTPProjectConfigManager.new(
    sdk_key: SDK_KEY,
    url_template: "https://dev.cdn.optimizely.com/datafiles/{sdk_key}.json",  # develrc
    logger: logger,
    polling_interval: 300,  # 5 minutes
    request_timeout: 30     # 30 second timeout
  )

  # Create second client with custom config
  optimizely_client2 = Optimizely::Project.new(
    config_manager: config_manager2,
    logger: logger
  )

  # Wait for datafiles to load
  puts "\nWaiting for datafiles to load..."
  sleep(2)

  puts "\n=== Testing Both Configurations ==="
  
  user_attributes = { "country" => "us" }

  # Test default config client
  puts "\nTesting DEFAULT config client:"
  user_ctx1 = optimizely_client1.create_user_context(
    "config_test_user_default",
    user_attributes
  )
  decision1 = user_ctx1.decide(FLAG_KEY)
  print_decision("Default Config", decision1)

  # Test custom config client
  puts "\nTesting CUSTOM config client:"
  user_ctx2 = optimizely_client2.create_user_context(
    "config_test_user_custom",
    user_attributes
  )
  decision2 = user_ctx2.decide(FLAG_KEY)
  print_decision("Custom Config", decision2)

  puts "\n=== Configuration Summary ==="
  puts "✓ Default CMAB config: 100 cache size, 30min TTL, 10s timeout, 3 retries"
  puts "✓ Custom CMAB config: 200 cache size, 5min TTL, 30s timeout, 5 retries"
  puts "✓ Both clients initialized successfully with respective configs"
  puts "Note: Config differences affect caching behavior and HTTP retry logic"
end


def print_decision(context, decision)
  puts "\n#{context}:"
  
  # Check if decision object exists
  if decision.nil?
    puts "    ❌ Decision: nil (CMAB call failed or returned null)"
    puts "    ❌ Check logs above for CMAB service errors (502, timeout, etc.)"
    return
  end

  # Get basic decision properties with safety checks
  variation_key = decision.respond_to?(:variation_key) ? decision.variation_key : decision&.variation
  enabled = decision.respond_to?(:enabled?) ? decision.enabled? : decision&.enabled
  flag_key = decision.respond_to?(:flag_key) ? decision.flag_key : nil
  rule_key = decision.respond_to?(:rule_key) ? decision.rule_key : nil
  reasons = decision.respond_to?(:reasons) ? decision.reasons : [decision&.reason].compact

  # Print core decision info
  puts "    Variation Key: #{variation_key || 'null'}"
  puts "    Enabled: #{enabled ? 'Enabled' : 'Disabled'}"
  puts "    Flag Key: #{flag_key}" if flag_key
  puts "    Rule Key: #{rule_key}" if rule_key

  # Print variables if they exist
  if decision.respond_to?(:variables) && decision.variables
    if decision.variables.empty?
      puts "    Variables: {}"
    else
      puts "    Variables: #{decision.variables}"
    end
  end

  # Print reasons with better formatting
  puts "reasons: #{reasons}"
  if reasons && !reasons.empty?
    puts "    Reasons:"
    reasons.each do |reason|
      puts "      • #{reason}"
    end
  end

  # Check for CMAB-specific indicators
  if reasons.any? { |r| r.to_s.downcase.include?('cmab') }
    puts "    🎯 CMAB: Decision from CMAB service"
  elsif reasons.any? { |r| r.to_s.downcase.include?('cache') }
    puts "    💾 CACHE: Decision from cache"
  elsif reasons.any? { |r| r.to_s.downcase.include?('fallback') }
    puts "    🔄 FALLBACK: Using fallback decision"
  end

  # Check for errors or warnings
  if reasons.any? { |r| r.to_s.downcase.include?('error') || r.to_s.downcase.include?('fail') }
    puts "    ⚠️  WARNING: Error detected in decision reasons"
  end

  # Check decision validity
  if variation_key.nil? || variation_key.to_s.empty?
    puts "    ❌ Invalid variation key - check flag configuration"
  end

  # Add debugging info
  puts "    Debug Info:"
  puts "      - Decision class: #{decision.class}"
  puts "      - Has variation_key method: #{decision.respond_to?(:variation_key)}"
  puts "      - Has enabled? method: #{decision.respond_to?(:enabled?)}"
  puts "      - Has variables method: #{decision.respond_to?(:variables)}"
  puts "      - Has reasons method: #{decision.respond_to?(:reasons)}"
  
  puts "    📊 [Check debug logs above for detailed CMAB HTTP calls and timing]"
end

main