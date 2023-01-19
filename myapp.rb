require 'optimizely'
require 'optimizely/optimizely_factory'
require "logger"


# Initialize an Optimizely client
optimizely_client = Optimizely::OptimizelyFactory.custom_instance('TbrfRLeKvLyWGusqANoeR', nil, nil, logger=Optimizely::SimpleLogger.new(Logger::INFO))

# config = optimizely_client.get_optimizely_config

attributes = {"laptop_os" => "mac"}

# user = optimizely_client.create_user_context('12345', attributes)    # regular attributes, user context takes any user id - important when running these 3 lines I need to adjust the audience in the app (use the correct one)!!!
user = optimizely_client.create_user_context('fs-id-12', attributes)    # prebuilt segments (no lists), valid user id is fs-id-12 (matches DOB)
# user = optimizely_client.create_user_context('fs-id-6', attributes)    # list segment, valid use is fs-id-6

sleep(1)    # sleep is needed for datafile to load - check this, might be an issue

user.fetch_qualified_segments()
segments = user.qualified_segments()

if segments
    puts "  >>> SEGMENTS when segmnents exist: #{segments}"
else
    puts "  >>> SEGMENTS when no segments: #{segments}"
end

decide_options = [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS]
decision = user.decide('flag1', decide_options)
puts "\n >>> DECISION #{decision.as_json()}"

user.track_event("myevent")

optimizely_client.close()
