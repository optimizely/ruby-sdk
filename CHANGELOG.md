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
