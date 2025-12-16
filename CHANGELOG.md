# Optimizely Ruby SDK Changelog

## 5.2.1
December 17th, 2025

### New Features  
- Resolved issues with Holdout impression event handling and notification delivery. ([#382](https://github.com/optimizely/ruby-sdk/pull/382))  


## 5.2.0
November 13th, 2025

### New Features  
- Added CMAB client implementation to support contextual multi-armed bandit decisioning. ([#364](https://github.com/optimizely/ruby-sdk/pull/364))  
- Implemented CMAB service to manage contextual decision logic. ([#367](https://github.com/optimizely/ruby-sdk/pull/367))  
- Added SDK multi-region support for data hosting. ([#365](https://github.com/optimizely/ruby-sdk/pull/365))  

### Enhancements  
- Added `experiment_id` and `variation_id` to event payloads. ([#361](https://github.com/optimizely/ruby-sdk/pull/361))  
- Updated project config to track CMAB properties. ([#362](https://github.com/optimizely/ruby-sdk/pull/362))  
- Added `remove` method in LRU Cache for CMAB service. ([#366](https://github.com/optimizely/ruby-sdk/pull/366))  
- Implemented Decision Service methods to handle CMAB logic. ([#369](https://github.com/optimizely/ruby-sdk/pull/369))  
- Updated impression events to include CMAB UUID. ([#370](https://github.com/optimizely/ruby-sdk/pull/370))  
- Exposed CMAB prediction endpoint in URL template. ([#378](https://github.com/optimizely/ruby-sdk/pull/378))  

### Bug Fixes  
- Fixed Rubocop failures on Ruby 3.0.0. ([#371](https://github.com/optimizely/ruby-sdk/pull/371))  
- Fixed concurrency issue in CMAB service. ([#375](https://github.com/optimizely/ruby-sdk/pull/375))  
- Minor bugbash updates and stability improvements. ([#377](https://github.com/optimizely/ruby-sdk/pull/377))  


## 5.1.0
January 10th, 2025

Added support for batch processing in DecideAll and DecideForKeys, enabling more efficient handling of multiple decisions in the User Profile Service.([#353](https://github.com/optimizely/ruby-sdk/pull/353))

## 5.0.1
February 8th, 2024

The 5.0.1 minor release introduces update of metadata in gemspec.

## 5.0.0
January 18th, 2024

### New Features

The 5.0.0 release introduces a new primary feature, [Advanced Audience Targeting]( https://docs.developers.optimizely.com/feature-experimentation/docs/optimizely-data-platform-advanced-audience-targeting) enabled through integration with [Optimizely Data Platform (ODP)](https://docs.developers.optimizely.com/optimizely-data-platform/docs)
([#303](https://github.com/optimizely/ruby-sdk/pull/303),
[#308](https://github.com/optimizely/ruby-sdk/pull/308),
[#310](https://github.com/optimizely/ruby-sdk/pull/310),
[#311](https://github.com/optimizely/ruby-sdk/pull/311),
[#312](https://github.com/optimizely/ruby-sdk/pull/312),
[#314](https://github.com/optimizely/ruby-sdk/pull/314),
[#316](https://github.com/optimizely/ruby-sdk/pull/316)).
You can use ODP, a high-performance [Customer Data Platform (CDP)]( https://www.optimizely.com/optimization-glossary/customer-data-platform/), to easily create complex real-time segments (RTS) using first-party and 50+ third-party data sources out of the box. You can create custom schemas that support the user attributes important for your business, and stitch together user behavior done on different devices to better understand and target your customers for personalized user experiences. ODP can be used as a single source of truth for these segments in any Optimizely or 3rd party tool.

With ODP accounts integrated into Optimizely projects, you can build audiences using segments pre-defined in ODP. The SDK will fetch the segments for given users and make decisions using the segments. For access to ODP audience targeting in your Feature Experimentation account, please contact your Optimizely Customer Success Manager.

This version includes the following changes:

* New API added to `OptimizelyUserContext`:

    * `fetch_qualified_segments()`: this API will retrieve user segments from the ODP server. The fetched segments will be used for audience evaluation. The fetched data will be stored in the local cache to avoid repeated network delays.

    * When an `OptimizelyUserContext` is created, the SDK will automatically send an identify request to the ODP server to facilitate observing user activities.

* New APIs added to `Optimizely::Project`:

    * `send_odp_event()`: customers can build/send arbitrary ODP events that will bind user identifiers and data to user profiles in ODP.

For details, refer to our documentation pages:

* [Advanced Audience Targeting](https://docs.developers.optimizely.com/feature-experimentation/docs/optimizely-data-platform-advanced-audience-targeting)

* [Server SDK Support](https://docs.developers.optimizely.com/feature-experimentation/v1.0/docs/advanced-audience-targeting-for-server-side-sdks)

* [Initialize Ruby SDK](https://docs.developers.optimizely.com/feature-experimentation/docs/initialize-sdk-ruby)

* [OptimizelyUserContext Ruby SDK](https://docs.developers.optimizely.com/feature-experimentation/docs/optimizelyusercontext-ruby)

* [Advanced Audience Targeting segment qualification methods](https://docs.developers.optimizely.com/feature-experimentation/docs/advanced-audience-targeting-segment-qualification-methods-ruby)

* [Send Optimizely Data Platform data using Advanced Audience Targeting](https://docs.developers.optimizely.com/feature-experimentation/docs/send-odp-data-using-advanced-audience-targeting-ruby)

### Logging

* Add warning to polling intervals below 30 seconds ([#338](https://github.com/optimizely/ruby-sdk/pull/338))
* Add warning to duplicate experiment keys ([#343](https://github.com/optimizely/ruby-sdk/pull/343))

### Enhancements
* Removed polling config manager stop restriction, allowing it to be restarted ([#340](https://github.com/optimizely/ruby-sdk/pull/340)).
* Include object id/key in invalid object errors ([#301](https://github.com/optimizely/ruby-sdk/pull/301)).

### Breaking Changes

* Updated required Ruby version from 2.7 -> 3.0
* `Optimizely::Project` initialization arguments have been changed from positional to keyword ([#342](https://github.com/optimizely/ruby-sdk/pull/342)).
* `ODPManager` in the SDK is enabled by default. Unless an ODP account is integrated into the Optimizely projects, most `ODPManager` functions will be ignored. If needed, `ODPManager` can be disabled when `Optimizely::Project` is instantiated.

* `ProjectConfigManager` interface now requires a `sdk_key` method ([#323](https://github.com/optimizely/ruby-sdk/pull/323)).
* `HTTPProjectConfigManager` requires either the `sdk_key` parameter or a datafile containing an sdkKey ([#323](https://github.com/optimizely/ruby-sdk/pull/323)).
* `BatchEventProcessor` is now the default `EventProcessor` when `Optimizely::Project` is instantiated ([#325](https://github.com/optimizely/ruby-sdk/pull/325)).

## 5.0.0-beta
April 28th, 2023

### New Features

The 5.0.0-beta release introduces a new primary feature, [Advanced Audience Targeting]( https://docs.developers.optimizely.com/feature-experimentation/docs/optimizely-data-platform-advanced-audience-targeting) enabled through integration with [Optimizely Data Platform (ODP)](https://docs.developers.optimizely.com/optimizely-data-platform/docs)
([#303](https://github.com/optimizely/ruby-sdk/pull/303),
[#308](https://github.com/optimizely/ruby-sdk/pull/308),
[#310](https://github.com/optimizely/ruby-sdk/pull/310),
[#311](https://github.com/optimizely/ruby-sdk/pull/311),
[#312](https://github.com/optimizely/ruby-sdk/pull/312),
[#314](https://github.com/optimizely/ruby-sdk/pull/314),
[#316](https://github.com/optimizely/ruby-sdk/pull/316)).
You can use ODP, a high-performance [Customer Data Platform (CDP)]( https://www.optimizely.com/optimization-glossary/customer-data-platform/), to easily create complex real-time segments (RTS) using first-party and 50+ third-party data sources out of the box. You can create custom schemas that support the user attributes important for your business, and stitch together user behavior done on different devices to better understand and target your customers for personalized user experiences. ODP can be used as a single source of truth for these segments in any Optimizely or 3rd party tool.

With ODP accounts integrated into Optimizely projects, you can build audiences using segments pre-defined in ODP. The SDK will fetch the segments for given users and make decisions using the segments. For access to ODP audience targeting in your Feature Experimentation account, please contact your Optimizely Customer Success Manager.

This version includes the following changes:

* New API added to `OptimizelyUserContext`:

    * `fetch_qualified_segments()`: this API will retrieve user segments from the ODP server. The fetched segments will be used for audience evaluation. The fetched data will be stored in the local cache to avoid repeated network delays.

    * When an `OptimizelyUserContext` is created, the SDK will automatically send an identify request to the ODP server to facilitate observing user activities.

* New APIs added to `Optimizely::Project`:

    * `send_odp_event()`: customers can build/send arbitrary ODP events that will bind user identifiers and data to user profiles in ODP.

For details, refer to our documentation pages:

* [Advanced Audience Targeting](https://docs.developers.optimizely.com/feature-experimentation/docs/optimizely-data-platform-advanced-audience-targeting)

* [Server SDK Support](https://docs.developers.optimizely.com/feature-experimentation/v1.0/docs/advanced-audience-targeting-for-server-side-sdks)

* [Initialize Ruby SDK](https://docs.developers.optimizely.com/feature-experimentation/docs/initialize-sdk-ruby)

* [OptimizelyUserContext Ruby SDK](https://docs.developers.optimizely.com/feature-experimentation/docs/optimizelyusercontext-ruby)

* [Advanced Audience Targeting segment qualification methods](https://docs.developers.optimizely.com/feature-experimentation/docs/advanced-audience-targeting-segment-qualification-methods-ruby)

* [Send Optimizely Data Platform data using Advanced Audience Targeting](https://docs.developers.optimizely.com/feature-experimentation/docs/send-odp-data-using-advanced-audience-targeting-ruby)

### Breaking Changes

* `ODPManager` in the SDK is enabled by default. Unless an ODP account is integrated into the Optimizely projects, most `ODPManager` functions will be ignored. If needed, `ODPManager` can be disabled when `Optimizely::Project` is instantiated.

* `ProjectConfigManager` interface now requires a `sdk_key` method ([#323](https://github.com/optimizely/ruby-sdk/pull/323)).
* `HTTPProjectConfigManager` requires either the `sdk_key` parameter or a datafile containing an sdkKey ([#323](https://github.com/optimizely/ruby-sdk/pull/323)).
* `BatchEventProcessor` is now the default `EventProcessor` when `Optimizely::Project` is instantiated ([#325](https://github.com/optimizely/ruby-sdk/pull/325)).

## 4.0.1
March 13th, 2023

We updated our README.md and other non-functional code to reflect that this SDK supports both Optimizely Feature Experimentation and Optimizely Full Stack. ([#327](https://github.com/optimizely/ruby-sdk/pull/327))

## 4.0.0
August 4, 2022

### Breaking Changes:
* Changed official supported versions of Ruby to 2.7, 3.0 and 3.1

## 3.10.1
February 2, 2022

### Enhancements:
- Generate OptimizelyConfig object on API Call instead of SDK initialization to make the initialization faster ([#296](https://github.com/optimizely/ruby-sdk/pull/296)).

## 3.10.0
January 11, 2022

### New Features:
- Add a set of new APIs for overriding and managing user-level flag, experiment and delivery rule decisions. These methods can be used for QA and automated testing purposes. They are an extension of the OptimizelyUserContext interface ([#287](https://github.com/optimizely/ruby-sdk/pull/287), [#288](https://github.com/optimizely/ruby-sdk/pull/288), [#289](https://github.com/optimizely/ruby-sdk/pull/289), [#290](https://github.com/optimizely/ruby-sdk/pull/290), [#291](https://github.com/optimizely/ruby-sdk/pull/291), [#293](https://github.com/optimizely/ruby-sdk/pull/293)):
	- setForcedDecision
	- getForcedDecision
	- removeForcedDecision
	- removeAllForcedDecisions

- For details, refer to our documentation pages: [OptimizelyUserContext](https://docs.developers.optimizely.com/full-stack/v4.0/docs/optimizelyusercontext-ruby) and [Forced Decision methods](https://docs.developers.optimizely.com/full-stack/v4.0/docs/forced-decision-methods-ruby).

## 3.9.0
September 16, 2021

### New Features:
- Add new public properties to `OptimizelyConfig`. ([#285](https://github.com/optimizely/ruby-sdk/pull/285))
	- sdkKey
 	- environmentKey
	- attributes
	- audiences
	- events
	- experimentRules and deliveryRules to `OptimizelyFeature`
	- audiences to `OptimizelyExperiment`
- For details, refer to our documentation page: [https://docs.developers.optimizely.com/full-stack/v4.0/docs/optimizelyconfig-ruby](https://docs.developers.optimizely.com/full-stack/v4.0/docs/optimizelyconfig-ruby).

### Deprecated:
- `OptimizelyFeature.experimentsMap` of `OptimizelyConfig` is deprecated as of this release. Please use `OptimizelyFeature.experimentRules` and `OptimizelyFeature.deliveryRules`. ([#285](https://github.com/optimizely/ruby-sdk/pull/285))

## 3.8.1
August 2nd, 2021

### Bug Fixes:
- Fixed duplicate experiment key issue with multiple feature flags. While trying to get variation from the variationKeyMap, it was unable to find because the latest experimentKey was overriding the previous one. [#282](https://github.com/optimizely/ruby-sdk/pull/282)

## 3.8.0
February 16th, 2021

### New Features:
- Introducing a new primary interface for retrieving feature flag status, configuration and associated experiment decisions for users ([#274](https://github.com/optimizely/ruby-sdk/pull/274), [#279](https://github.com/optimizely/ruby-sdk/pull/279)). The new `OptimizelyUserContext` class is instantiated with `create_user_context` and exposes the following APIs to get `OptimizelyDecision`:

    - set_attribute
    - decide
    - decide_all
    - decide_for_keys
    - track_event

- For details, refer to our documentation page: https://docs.developers.optimizely.com/full-stack/v4.0/docs/ruby-sdk.

## 3.7.0
November 20th, 2020

### New Features:
- Added support for upcoming application-controlled introduction of tracking for non-experiment Flag decisions. ([#272](https://github.com/optimizely/ruby-sdk/pull/272)).
- Added "enabled" field to decision metadata structure ([#275](https://github.com/optimizely/ruby-sdk/pull/275)).

## 3.6.0
September 30th, 2020

### New Features:
- Add support for Semantic Versioning in Audience Evaluation ([#267](https://github.com/optimizely/ruby-sdk/pull/267)).
- Add datafile accessor to config ([#268](https://github.com/optimizely/ruby-sdk/pull/268)).

### Bug Fixes:
- Modify log messages to be explicit when it's evaluating an experiment and when it's doing so for a rollout ([#259](https://github.com/optimizely/ruby-sdk/pull/259)).

## 3.5.0
July 9th, 2020

### New Features:
- Add support for JSON feature variables ([#251](https://github.com/optimizely/ruby-sdk/pull/251))
- Add support for authenticated datafiles ([#255](https://github.com/optimizely/ruby-sdk/pull/255))
- Added support for authenticated datafiles. `HTTPProjectConfigManager` now accepts `datafile_access_token` to be able to fetch authenticated datafiles.
- Add support for proxy server for http config manager. ([#262](https://github.com/optimizely/ruby-sdk/pull/262))

### Bug Fixes:
- Handle error with error handler in async scheduler ([#248](https://github.com/optimizely/ruby-sdk/pull/248)).
- Change single audience result to debug ([#254](https://github.com/optimizely/ruby-sdk/pull/254)).

## 3.5.0-beta
June 17th, 2020

### New Features:
- Add support for JSON feature variables ([#251](https://github.com/optimizely/ruby-sdk/pull/251))
- Add support for authenticated datafiles ([#255](https://github.com/optimizely/ruby-sdk/pull/255))

### Bug Fixes:
- Handle error with error handler in async scheduler ([#248](https://github.com/optimizely/ruby-sdk/pull/248)).
- Change single audience result to debug ([#254](https://github.com/optimizely/ruby-sdk/pull/254)).

## 3.4.0
January 23rd, 2020

### New Features:
- Added a new API to get a project configuration static data.
  - Call `get_optimizely_config` to get a snapshot copy of project configuration static data.
  - It returns an `OptimizelyConfig` instance which includes a datafile revision number, all experiments, and feature flags mapped by their key values.
  - Added caching for `get_optimizely_config` - `OptimizelyConfig` object will be cached and reused for the lifetime of the datafile
  - For details, refer to a documentation page: https://docs.developers.optimizely.com/full-stack/docs/optimizelyconfig-ruby


## 3.3.2
December 13th, 2019

### Bug Fixes:
- BatchEventProcessor will hang on poll after flushing with no event if no event count is greater than 3 [#224](https://github.com/optimizely/ruby-sdk/pull/224).
- EventDispatcher logs debug response and error responses from http post call i[#221](https://github.com/optimizely/ruby-sdk/pull/221).

### New Features
- NotificationCenter should accept any Callable [#219](https://github.com/optimizely/ruby-sdk/pull/219).

## 3.3.1
October 10th, 2019

### Bug Fixes:
- Include LICENSE file in built gem ([#208](https://github.com/optimizely/ruby-sdk/pull/190)) as per rubygems guidelines around license files.

## 3.3.0
September 26th, 2019

### New Features:
- Added non-typed `get_feature_variable` method ([#190](https://github.com/optimizely/ruby-sdk/pull/190)) as a more idiomatic approach to getting values of feature variables.
  - Typed `get_feature_variable` methods will still be available for use.
- Added support for event batching via the event processor.
- Events generated by methods like `activate`, `track`, and `is_feature_enabled` will be held in a queue until the configured batch size is reached, or the configured flush interval has elapsed. Then, they will be batched into a single payload and sent to the event dispatcher.
- To configure event batching, set the `batch_size` and `flush_interval` properties in the `OptimizelyFactory` using `OptimizelyFactory.max_event_batch_size(batch_size, logger)` and `OptimizelyFactory.max_event_flush_interval(flush_interval, logger)` and then create `OptimizelyFactory.custom_instance`.
- Event batching is enabled by default. `batch_size` defaults to `10`. `flush_interval` defaults to `30000` milliseconds.
- Added the `close` method representing the process of closing the instance. When `close` is called, any events waiting to be sent as part of a batched event request will be immediately batched and sent to the event dispatcher.

### Deprecated
- `EventBuilder` was deprecated and now we will be using `UserEventFactory` and `EventFactory` to create logEvents.
- `LogEvent` was deprecated from `Activate` and `Track` notifications in favor of explicit `LogEvent` notification.

## 3.2.0
July 25th, 2019

### New Features:
* Added support for automatic datafile management via `HTTPProjectConfigManager`:
  * The [`HTTPProjectConfigManager`](https://github.com/optimizely/ruby-sdk/blob/master/lib/optimizely/config_manager/http_project_config_manager.rb) is an implementation of the Interface
      [`ProjectConfigManager`](https://github.com/optimizely/ruby-sdk/blob/master/lib/optimizely/config_manager/project_config_manager.rb).
    - Users must first build the `HTTPProjectConfigManager` with an SDK key and then provide that instance to the `Optimizely` instance.
    - An initial datafile can be provided to the `HTTPProjectConfigManager` to bootstrap before making HTTP requests for the hosted datafile.
    - Requests for the datafile are made in a separate thread and are scheduled with fixed delay.
    - Configuration updates can be subscribed to via the NotificationCenter built with the `HTTPProjectConfigManager`.
    - `Optimizely` instance must be disposed after the use or `HTTPProjectConfigManager` must be disposed after the use to release resources.
- The [`OptimizelyFactory`](https://github.com/optimizely/ruby-sdk/blob/master/lib/optimizely/optimizely_factory.rb) provides basic methods for instantiating the Optimizely SDK with a minimal number of parameters. Check [`README.md`](https://github.com/optimizely/ruby-sdk#initialization-by-optimizelyfactory) for more details.

## 3.1.1
May 30th, 2019

### Bug Fixes:
- fix(is_feature_enabled): Added rollout experiment key map for onboarding datafile. ([#168](https://github.com/optimizely/ruby-sdk/pull/168))

## 3.1.0
May 3rd, 2019

### New Features:
- Introduced Decision notification listener to be able to record:
    - Variation assignments for users activated in an experiment.
    - Feature access for users.
    - Feature variable value for users.

### Bug Fixes:
- Feature variable APIs return default variable value when featureEnabled property is false. ([#162](https://github.com/optimizely/ruby-sdk/pull/162))

### Deprecated:
- Activate notification listener is deprecated as of this release. Recommendation is to use the new Decision notification listener. Activate notification listener will be removed in the next major release.

## 3.0.0
March 8th, 2019

The 3.0 release improves event tracking and supports additional audience targeting functionality.
### New Features:
* Event tracking:
  * The `track` method now dispatches its conversion event _unconditionally_, without first determining whether the user is targeted by a known experiment that uses the event. This may increase outbound network traffic.
  * In Optimizely results, conversion events sent by 3.0 SDKs don't explicitly name the experiments and variations that are currently targeted to the user. Instead, conversions are automatically attributed to variations that the user has previously seen, as long as those variations were served via 3.0 SDKs or by other clients capable of automatic attribution, and as long as our backend actually received the impression events for those variations.
  * Altogether, this allows you to track conversion events and attribute them to variations even when you don't know all of a user's attribute values, and even if the user's attribute values or the experiment's configuration have changed such that the user is no longer affected by the experiment. As a result, **you may observe an increase in the conversion rate for previously-instrumented events.** If that is undesirable, you can reset the results of previously-running experiments after upgrading to the 3.0 SDK.
  * This will also allow you to attribute events to variations from other Optimizely projects in your account, even though those experiments don't appear in the same datafile.
  * Note that for results segmentation in Optimizely results, the user attribute values from one event are automatically applied to all other events in the same session, as long as the events in question were actually received by our backend. This behavior was already in place and is not affected by the 3.0 release.
* Support for all types of attribute values, not just strings.
  * All values are passed through to notification listeners.
  * Strings, booleans, and valid numbers are passed to the event dispatcher and can be used for Optimizely results segmentation. A valid number is a finite Numeric in the inclusive range [-2⁵³, 2⁵³].
  * Strings, booleans, and valid numbers are relevant for audience conditions.
* Support for additional matchers in audience conditions:
  * An `exists` matcher that passes if the user has a non-null value for the targeted user attribute and fails otherwise.
  * A `substring` matcher that resolves if the user has a string value for the targeted attribute.
  * `gt` (greater than) and `lt` (less than) matchers that resolve if the user has a valid number value for the targeted attribute. A valid number is a finite Numeric in the inclusive range [-2⁵³, 2⁵³].
  * The original (`exact`) matcher can now be used to target booleans and valid numbers, not just strings.
* Support for A/B tests, feature tests, and feature rollouts whose audiences are combined using `"and"` and `"not"` operators, not just the `"or"` operator.
* Datafile-version compatibility check: The SDK will remain uninitialized (i.e., will gracefully fail to activate experiments and features) if given a datafile version greater than 4.
* Updated Pull Request template and commit message guidelines.

### Breaking Changes:
* Conversion events sent by 3.0 SDKs don't explicitly name the experiments and variations that are currently targeted to the user, so these events are unattributed in raw events data export. You must use the new _results_ export to determine the variations to which events have been attributed.
* Previously, notification listeners were only given string-valued user attributes because only strings could be passed into various method calls. That is no longer the case. You may pass non-string attribute values, and if you do, you must update your notification listeners to be able to receive whatever values you pass in.

### Bug Fixes:
* Experiments and features can no longer activate when a negatively targeted attribute has a missing, null, or malformed value.
  * Audience conditions (except for the new `exists` matcher) no longer resolve to `false` when they fail to find an legitimate value for the targeted user attribute. The result remains `null` (unknown). Therefore, an audience that negates such a condition (using the `"not"` operator) can no longer resolve to `true` unless there is an unrelated branch in the condition tree that itself resolves to `true`.
* `setForcedVariation` now treats an empty variation key as invalid and does not reset the variation.
* All methods now validate that user IDs are strings and that experiment keys, feature keys, feature variable keys, and event keys are non-empty strings.


## 2.1.1
October 11th, 2018

### Bug Fixes
- fix(track): Send decisions for all experiments using an event when using track ([#120](https://github.com/optimizely/ruby-sdk/pull/120)).
- EventBuilder uses the same logger as Project ([#122](https://github.com/optimizely/ruby-sdk/pull/122)).
- Updating libraries for Ruby SDK ([#123](https://github.com/optimizely/ruby-sdk/pull/123)).
- fix(datafile-parsing): Prevent newer versions datafile ([#124](https://github.com/optimizely/ruby-sdk/pull/124)).

## 2.1.0
July 2nd, 2018

- Introduces support for bot filtering ([#106](https://github.com/optimizely/ruby-sdk/pull/106)).

## 2.0.3
June 25th, 2018

### Bug Fixes
Fixes [#109](https://github.com/optimizely/ruby-sdk/issues/109)

## 2.0.2
June 19th, 2018

- Fix: send impression event for Feature Test when Feature is disabled ([#110](https://github.com/optimizely/ruby-sdk/pull/110)).

## 2.0.1
April 25th, 2018

### Bug Fixes
Fixes [#101](https://github.com/optimizely/ruby-sdk/issues/101)

## 2.0.0
April 12th, 2018

This major release of the Optimizely SDK introduces APIs for Feature Management. It also introduces some breaking changes listed below.

### New Features
* Introduces the `is_feature_enabled` API to determine whether to show a feature to a user or not.
```
enabled = optimizely_client.is_feature_enabled('my_feature_key', 'user_1', user_attributes)
```

* You can also get all the enabled features for the user by calling the following method which returns a list of strings representing the feature keys:
```
enabled_features = optimizely_client.get_enabled_features('user_1', user_attributes)
```

* Introduces Feature Variables to configure or parameterize your feature. There are four variable types: `Integer`, `String`, `Double`, `Boolean`.
```
string_variable = optimizely_client.get_feature_variable_string('my_feature_key', 'string_variable_key', 'user_1')
integer_variable = optimizely_client.get_feature_variable_integer('my_feature_key', 'integer_variable_key', 'user_1')
double_variable = optimizely_client.get_feature_variable_double('my_feature_key', 'double_variable_key', 'user_1')
boolean_variable = optimizely_client.get_feature_variable_boolean('my_feature_key', 'boolean_variable_key', 'user_1')
```

### Breaking changes
* The `track` API with revenue value as a stand-alone parameter has been removed. The revenue value should be passed in as an entry of the event tags map. The key for the revenue tag is `revenue` and will be treated by Optimizely as the key for analyzing revenue data in results.
```
event_tags = {
  'revenue'=> 1200
}

optimizely_client.track('event_key', 'user_id', user_attributes, event_tags)
```

## 2.0.0.beta1
March 29th, 2018

This major release of the Optimizely SDK introduces APIs for Feature Management. It also introduces some breaking changes listed below.

### New Features
* Introduces the `is_feature_enabled` API to determine whether to show a feature to a user or not.
```
enabled = optimizely_client.is_feature_enabled('my_feature_key', 'user_1', user_attributes)
```

* You can also get all the enabled features for the user by calling the following method which returns a list of strings representing the feature keys:
```
enabled_features = optimizely_client.get_enabled_features('user_1', user_attributes)
```

* Introduces Feature Variables to configure or parameterize your feature. There are four variable types: `Integer`, `String`, `Double`, `Boolean`.
```
string_variable = optimizely_client.get_feature_variable_string('my_feature_key', 'string_variable_key', 'user_1')
integer_variable = optimizely_client.get_feature_variable_integer('my_feature_key', 'integer_variable_key', 'user_1')
double_variable = optimizely_client.get_feature_variable_double('my_feature_key', 'double_variable_key', 'user_1')
boolean_variable = optimizely_client.get_feature_variable_boolean('my_feature_key', 'boolean_variable_key', 'user_1')
```

### Breaking changes
* The `track` API with revenue value as a stand-alone parameter has been removed. The revenue value should be passed in as an entry of the event tags map. The key for the revenue tag is `revenue` and will be treated by Optimizely as the key for analyzing revenue data in results.
```
event_tags = {
  'revenue'=> 1200
}

optimizely_client.track('event_key', 'user_id', user_attributes, event_tags)
```

## 1.5.0
December 13, 2017

* Implemented IP anonymization.
* Implemented bucketing IDs.
* Implemented Notification Listeners.
-------------------------------------------------------------------------------
## 1.4.0
October 3, 2017

### New Features
* Introduce Numeric Metrics - This allows you to include a floating point value that is used to track numeric values in your experiments.
```
event_tags = {
  'category' => 'shoes',
  'value' => 13.37 # reserved 'value' tag
}
optimizely_client.track(event_key, user_id, attributes, event_tags)
```

* Introduce Forced Variation - This allows you to force users into variations programmatically in real time for QA purposes without requiring datafile downloads from the network.
```
result = optimizely_client.set_forced_variation(experiment_key, user_id, forced_variation_key)
```

* Upgrade to use new [event API](https://developers.optimizely.com/x/events/api/index.html).
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
2.0.0.beta
* Introduce feature flags and feature rollouts support.
* Introduce variable support via feature flags.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.3.0
* Introduce user profile service support.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.2.0
* Remove support for datafile version 1.
* Refactor order of bucketing operations.
* Always use Event Builder V2.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.1.2
* Send name of event tags instead of event ID.
* Update URL endpoint to the log server.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.1.1
* Gracefully handle empty traffic allocation ranges.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.1.0
* Introduce support for event tags.
* Add optional eventTags argument to track method signature.
* Deprecating optional eventValue argument in track method signature.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.0.2
* Change HTTParty version requirement to ~> 0.11, allowing HTTParty v0.14 (thanks @gaganawhad!)
* Relax murmurhash3 and json-schema version requirements to ~> 0.1 and ~> 2.6, respectively (thanks @gaganawhad!)
* Update Apache license headers.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.0.1
* Relax HTTParty version requirement.
* Add Apache license headers to source files.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
1.0.0
* Introduce support for Full Stack projects in Optimizely X with no breaking changes from previous version.
* Introduce more graceful exception handling in instantiation and core methods.
* Update whitelisting to take precedence over audience condition evaluation.
* Fix bug activating/tracking with an attribute not in the datafile.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
0.1.2
* Add support for V2 datafile and event endpoint.
* Change EventDispatcher / Event signature. The EventDispatcher's dispatch_event method now takes an Event with four properties: url (string URL to dispatch the Event to), params (Hash of params to send), http_verb (either :get or :post), and headers (Hash of headers to send with the request).
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
0.1.1
* Add option to skip JSON schema validation of datafile.
* Update datafile JSON schema.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
0.1.0
* Beta release of the Node SDK for server-side testing.
* Properly handle tracking events without valid experiments attached.
-------------------------------------------------------------------------------
