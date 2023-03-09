# frozen_string_literal: true

require 'optimizely'
require 'optimizely/optimizely_user_context'
require 'optimizely/optimizely_factory'
require 'optimizely/helpers/sdk_settings'
require 'optimizely/decide/optimizely_decide_option'
require 'logger'

def fetch_and_decide(user_ctx)
  # =========================================
  # Fetch Qualified Segments + decide
  # =========================================

  user_ctx.fetch_qualified_segments # to test segment options add one or both as argument: ['RESET_CACHE', 'IGNORE_CACHE']

  options = [Optimizely::Decide::OptimizelyDecideOption::INCLUDE_REASONS]
  decision = user_ctx.decide('flag1', options)
  puts(' >>> DECISION ', decision.as_json)

  segments = user_ctx.qualified_segments
  puts('  >>> SEGMENTS: ', segments)

  return unless segments

  segments.each do |segment|
    is_qualified = user.is_qualified_for(segment)
    puts('  >>> IS QUALIFIED: ', is_qualified)
  end
end

def send_event(optimizely_client)
  identifiers = {'fs-user-id': 'fs-id-12', 'email': 'fs-bash-x@optimizely.com'}

  # valid case
  optimizely_client.send_odp_event(type: 'any', identifiers: identifiers, action: 'any')

  # # test missing/empty identifiers should not be allowed
  optimizely_client.send_odp_event(action: 'any', identifiers: nil, type: 'any')
  optimizely_client.send_odp_event(action: 'any', identifiers: {}, type: 'any')

  # # test missing/empty action should not be allowed
  optimizely_client.send_odp_event(action: '', identifiers: identifiers, type: 'any')
  optimizely_client.send_odp_event(action: nil, identifiers: identifiers, type: 'any')
end

# ============================================
# CONFIG TYPE 1:
# default config, minimal settings
# ============================================

# TEST THE FOLLOWING:
# - test creating user context with regular attributes
# - test creating user context with prebuilt segments (no odp list), should get segments back, experiment should evaluate to true, decide response should look correct
#     - truth table - TBD
# - test creating user context  with prebuilt segment list, should get back a list of segments, experiment should evaluate to true, decide response should look correct
#     - may not need truth table test here (check)
# - add RESET_CACHE and/or IGNORE_CACHE to fetch qualified segments call and repeat
# - test send event
#     - verify events on ODP event inspector
# - in send_event function uncomment lines of code that test missing identifiers and action keys, verify appropriate error is produced
# - test audience segments (see spreadsheet
# - test implicit/explicit ODP events?
# - test integrations (no ODP integration added to project, integration is on, is off)

def config_1
  optimizely_client = Optimizely::OptimizelyFactory.custom_instance('TbrfRLeKvLyWGusqANoeR', nil, nil, Optimizely::SimpleLogger.new(Logger::DEBUG))

  attributes = {"laptop_os": 'mac'}

  # CASE 1 - REGULAR ATTRIBUTES, NO ODP
  user = optimizely_client.create_user_context('user123', attributes)

  # CASE 2 - PREBUILT SEGMENTS, NO LIST SEGMENTS, valid user id is fs-id-12 (matehces DOB)
  # IMPORTANT: before running - make sure that in app.optimizely AB experiment you switched audience to "audience2-prebuit segment (no list)"
  # user = optimizely_client.create_user_context('fs-id-12', attributes)

  # CASE 3 - SEGMENT LIST/ARRAY, valid user id is fs-id-6
  # IMPORTANT: before running - make sure that in app.optimizely AB experiment you switched audience to "audience3-prebuilt segment list"
  # user = optimizely_client.create_user_context('fs-id-6', attributes)

  fetch_and_decide(user)
  send_event(optimizely_client)

  optimizely_client.close
end

# ============================================
# CONFIG TYPE 2:
# with ODP integration changed at app.optimizely.com - changed public key or host url
# VALID API key/HOST url- should work, INVALID KEY/URL-should get errors
# ============================================

# TEST THE FOLLOWING:
# - test the same as in "CONFIG TYPE 1" but use invalid API key or HOST url
# - TODO clarify with Jae what to test here !!!

def config_2
  optimizely_client = Optimizely::OptimizelyFactory.custom_instance('TbrfRLeKvLyWGusqANoeR', nil, nil, Optimizely::SimpleLogger.new(Logger::DEBUG))

  attributes = {"laptop_os": 'mac'}

  # CASE 1 - REGULAR ATTRIBUTES, NO ODP
  user = optimizely_client.create_user_context('user123', attributes)

  # CASE 2 - PREBUILT SEGMENTS, NO LIST SEGMENTS, valid user id is fs-id-12 (matehces DOB)
  # user = optimizely_client.create_user_context('fs-id-12', attributes)

  # CASE 3 - SEGMENT LIST/ARRAY, valid user id is fs-id-6
  # user = optimizely_client.create_user_context('fs-id-6', attributes)

  fetch_and_decide(user)
  send_event(optimizely_client)

  optimizely_client.close
end

# ============================================
# CONFIG TYPE 3:
# with different ODP configuration options (odpdisabled, segments_cache_size etc)
# ============================================

# TEST THE FOLLOWING:
# same as in "CONFIG TYPE 1", but add config options to fetch qualified segments function, for example:
# - disable_odp
# - segments_cache_size
# - segments_cache_timeout_in_secs
# - odp_segments_cache
# - odp_segment_manager
# - odp_event_manager
# - odp_segment_request_timeout
# - odp_event_request_timeout
# - odp_event_flush_interval

# Observe responses and verity the correct behavior.

def config_3
  settings = Optimizely::Helpers::OptimizelySdkSettings.new(disable_odp: true, odp_event_request_timeout: 0)

  optimizely_client = Optimizely::OptimizelyFactory.custom_instance(
    'TbrfRLeKvLyWGusqANoeR', nil, nil, Optimizely::SimpleLogger.new(Logger::DEBUG), nil, false, nil, nil, nil, settings
  )

  attributes = {"laptop_os": 'mac'}

  # CASE 1 - REGULAR ATTRIBUTES, NO ODP
  user = optimizely_client.create_user_context('user123', attributes)

  # CASE 2 - PREBUILT SEGMENTS, NO LIST SEGMENTS, valid user id is fs-id-12 (matehces DOB)
  # user = optimizely_client.create_user_context('fs-id-12', attributes)

  # CASE 3 - SEGMENT LIST/ARRAY, valid user id is fs-id-6
  # user = optimizely_client.create_user_context('fs-id-6', attributes)

  fetch_and_decide(user)
  send_event(optimizely_client)

  optimizely_client.close
end

config_1
config_2
config_3
