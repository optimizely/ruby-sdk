# Optimizely Ruby SDK - AI Coding Agent Instructions

## Architecture Overview

This is the **Optimizely Ruby SDK** for A/B testing and feature flag management. Key architectural patterns:

### Core Components
- **`Optimizely::Project`** (`lib/optimizely.rb`): Main client class, entry point for all SDK operations
- **`DecisionService`** (`lib/optimizely/decision_service.rb`): Core bucketing logic with 7-step decision flow (status→forced→whitelist→sticky→audience→CMAB→hash)
- **`ProjectConfig`** (`lib/optimizely/config/`): Manages datafile parsing and experiment/feature configuration
- **Config Managers** (`lib/optimizely/config_manager/`): Handle datafile fetching - `HTTPProjectConfigManager` for polling, `StaticProjectConfigManager` for static files

### Data Flow Patterns
- **User Context**: `OptimizelyUserContext` wraps user ID + attributes for decision APIs
- **Decision Pipeline**: All feature flags/experiments flow through `DecisionService.get_variation_for_feature()` 
- **Event Processing**: `BatchEventProcessor` queues and batches impression/conversion events
- **CMAB Integration**: Contextual Multi-Armed Bandit system in `lib/optimizely/cmab/` for advanced optimization

## Development Workflows

### Testing
```bash
# Run all tests
bundle exec rake spec

# Run specific test file  
bundle exec rspec spec/decision_service_spec.rb

# Run linting
bundle exec rubocop
```

### Build & Gem Management
```bash
# Build gem locally
rake build  # outputs to /pkg/

# Run benchmarks
rake benchmark
```

## Project-Specific Conventions

### Ruby Patterns
- **Frozen string literals**: All files start with `# frozen_string_literal: true`
- **Module namespacing**: Everything under `Optimizely::` module
- **Struct for data**: Use `Struct.new()` for decision results (e.g., `DecisionService::Decision`)
- **Factory pattern**: `OptimizelyFactory` provides preset SDK configurations

### Naming Conventions
- **Experiment/Feature keys**: String identifiers from Optimizely dashboard
- **User bucketing**: `bucketing_id` vs `user_id` (can be different for sticky bucketing)
- **Decision sources**: `'EXPERIMENT'`, `'FEATURE_TEST'`, `'ROLLOUT'` constants in `DecisionService`

### Error Handling
- **Graceful degradation**: Invalid configs return `nil`/default values, never crash
- **Logging levels**: Use `Logger::ERROR`, `Logger::INFO`, `Logger::DEBUG` consistently  
- **User input validation**: `Helpers::Validator` validates all public API inputs

## Critical Integration Points

### Datafile Management
- **HTTPProjectConfigManager**: Polls Optimizely CDN every 5 minutes by default
- **Notification system**: Subscribe to `OPTIMIZELY_CONFIG_UPDATE` for datafile changes
- **ODP integration**: On datafile update, call `update_odp_config_on_datafile_update()`

### Event Architecture  
- **BatchEventProcessor**: Default 10 events/batch, 30s flush interval
- **Thread safety**: SDK spawns background threads for polling and event processing
- **Graceful shutdown**: Always call `optimizely.close()` to flush events

### Feature Flag Decision API
- **New pattern**: Use `decide()` API, not legacy `is_feature_enabled()`
- **Decision options**: `OptimizelyDecideOption` constants control behavior (exclude variables, include reasons, etc.)
- **Forced decisions**: Override bucketing via `set_forced_variation()` or user profile service

## Test Patterns
- **Spec location**: One spec file per class in `/spec/` directory
- **WebMock**: Mock HTTP requests in tests (`require 'webmock/rspec'`)
- **Test data**: Use `spec_params.rb` for shared test constants
- **Coverage**: Coveralls integration via GitHub Actions

## Common Gotchas
- **Thread spawning**: Initialize SDK after forking processes in web servers
- **Bucketing consistency**: Use same `bucketing_id` across SDK calls for sticky behavior  
- **CMAB caching**: Context-aware ML decisions cache by user - use appropriate cache invalidation options
- **ODP events**: Require at least one identifier, auto-add default event data

## Critical Memory Leak Prevention

### **NEVER** Initialize Project Per Request
```ruby
# ❌ MEMORY LEAK - Creates new threads every request
def get_optimizely_client
  Optimizely::Project.new(datafile: fetch_datafile)
end

# ✅ CORRECT - Singleton pattern with proper cleanup
class OptimizelyService
  def self.instance
    @instance ||= Optimizely::Project.new(datafile: fetch_datafile)
  end
  
  def self.reset!
    @instance&.close  # Critical: stops background threads
    @instance = nil
  end
end
```

### Thread Management
- **Background threads**: `Project.new()` spawns multiple threads (`BatchEventProcessor`, `OdpEventManager`, config polling)
- **Memory accumulation**: Each initialization creates new threads that persist until explicitly stopped
- **Proper cleanup**: Always call `optimizely_instance.close()` before dereferencing
- **Rails deployment**: Use singleton pattern or application-level initialization, never per-request

### Production Patterns
```ruby
# Application initialization (config/initializers/optimizely.rb)
OPTIMIZELY_CLIENT = Optimizely::Project.new(
  sdk_key: ENV['OPTIMIZELY_SDK_KEY']
)

# Graceful shutdown (config/application.rb)
at_exit { OPTIMIZELY_CLIENT&.close }
```
