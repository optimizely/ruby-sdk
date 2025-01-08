# Optimizely Ruby SDK

[![Build Status](https://github.com/optimizely/ruby-sdk/actions/workflows/ruby.yml/badge.svg?branch=master)](https://github.com/optimizely/ruby-sdk/actions/workflows/ruby.yml?query=branch%3Amaster)
[![Coverage Status](https://coveralls.io/repos/github/optimizely/ruby-sdk/badge.svg)](https://coveralls.io/github/optimizely/ruby-sdk)
[![Apache 2.0](https://img.shields.io/github/license/nebula-plugins/gradle-extra-configurations-plugin.svg)](http://www.apache.org/licenses/LICENSE-2.0)


This repository houses the Ruby SDK for use with Optimizely Feature Experimentation and Optimizely Full Stack (legacy).

Optimizely Feature Experimentation is an A/B testing and feature management tool for product development teams that enables you to experiment at every step. Using Optimizely Feature Experimentation allows for every feature on your roadmap to be an opportunity to discover hidden insights. Learn more at [Optimizely.com](https://www.optimizely.com/products/experiment/feature-experimentation/), or see the [developer documentation](https://docs.developers.optimizely.com/experimentation/v4.0.0-full-stack/docs/welcome).

Optimizely Rollouts is [free feature flags](https://www.optimizely.com/free-feature-flagging/) for development teams. You can easily roll out and roll back features in any application without code deploys, mitigating risk for every feature on your roadmap.

## Get Started

Refer to the [Ruby SDK's developer documentation](https://docs.developers.optimizely.com/experimentation/v4.0.0-full-stack/docs/ruby-sdk) for detailed instructions on getting started with using the SDK.

### Requirements

* Ruby 3.0+

### Install the SDK

The SDK is available through [RubyGems](https://rubygems.org/gems/optimizely-sdk). To install:

```
gem install optimizely-sdk
```

### Feature Management Access
To access the Feature Management configuration in the Optimizely dashboard, please contact your Optimizely customer success manager.

## Use the Ruby SDK

### Initialization

You can initialize the Optimizely instance in two ways: directly with a datafile, or by using a factory class, `OptimizelyFactory`, which provides methods to create an Optimizely instance with the default configuration.

#### Initialization with datafile

 Initialize Optimizely with a datafile. This datafile will be used as ProjectConfig throughout the life of the Optimizely instance.

 ```ruby
 optimizely_instance = Optimizely::Project.new(datafile: datafile)
 ```

#### Initialization by OptimizelyFactory

 1. Initialize Optimizely by providing an `sdk_key` and an optional `datafile`. This will initialize an HTTPConfigManager that makes an HTTP GET request to the URL (formed using your provided `sdk_key` and the default datafile CDN url template) to asynchronously download the project datafile at regular intervals and update ProjectConfig when a new datafile is received.

    ```ruby
    optimizely_instance = Optimizely::OptimizelyFactory.default_instance('put_your_sdk_key_here', datafile)
    ```

   When the `datafile` is given then it will be used initially before any update.

 2. Initialize Optimizely by providing a Config Manager that implements a `config` method. You can customize our `HTTPConfigManager` as needed.

    ```ruby
    custom_config_manager = CustomConfigManager.new
    optimizely_instance = Optimizely::OptimizelyFactory.default_instance_with_config_manager(custom_config_manager)
    ```

 3. Initialize Optimizely with required `sdk_key` and other optional arguments.

      ```ruby
       optimizely_instance = Optimizely::OptimizelyFactory.custom_instance(
          sdk_key,
          datafile,
          event_dispatcher,
          logger,
          error_handler,
          skip_json_validation,
          user_profile_service,
          config_manager,
          notification_center,
          event_processor
      )
      ```

**Note:** The SDK spawns multiple threads when initialized. These threads have infinite loops that are used for fetching the datafile, as well as batching and dispatching events in the background. When using in a web server that spawn multiple child processes, you need to initialize the SDK after those child processes or workers have been spawned.

#### HTTP Config Manager

The `HTTPConfigManager` asynchronously polls for datafiles from a specified URL at regular intervals by making HTTP requests.


```ruby
 http_project_config_manager = Optimizely::HTTPProjectConfigManager.new(
        sdk_key: nil,
        url: nil,
        datafile: nil,
        url_template: nil,
        auto_update: nil,
        polling_interval: nil,
        start_by_default: nil,
        blocking_timeout: nil,
        logger: nil,
        error_handler: nil,
        skip_json_validation: false,
        notification_center: notification_center,
        datafile_access_token: nil,
        proxy_config: nil
      )
```
**Note:** You must provide either the `sdk_key` or URL. If you provide both, the URL takes precedence. (This is a test sentence.)

**sdk_key**
The `sdk_key` is used to compose the outbound HTTP request to the default datafile location on the Optimizely CDN.

**datafile**
You can provide an initial datafile to bootstrap the  `DataFileProjectConfig`  so that it can be used immediately. The initial datafile also serves as a fallback datafile if HTTP connection cannot be established. The initial datafile will be discarded after the first successful datafile poll.

**polling_interval**
The polling interval is used to specify a fixed delay between consecutive HTTP requests for the datafile. Valid duration is greater than 0 and less than 2592000 seconds. Default is 5 minutes.

**url_template**
A string with placeholder `{sdk_key}` can be provided so that this template along with the provided `sdk_key` is used to form the target URL.

**start_by_default**
Boolean flag used to start the `AsyncScheduler` for datafile polling if set to `true`.

**blocking_timeout**
The blocking timeout period is used to specify a maximum time to wait for initial bootstrapping. Valid blocking timeout period is between 1 and 2592000 seconds. Default is 15 seconds.

**datafile_access_token**
An access token sent in an authorization header with the request to fetch private datafiles.

You may also provide your own logger, error handler, or notification center.


#### Advanced configuration
The following properties can be set to override the default configurations for `HTTPConfigManager`.

| **PropertyName** | **Default Value** | **Description**
| -- | -- | --
| update_interval | 5 minutes | Fixed delay between fetches for the datafile
| sdk_key | nil | Optimizely project SDK key
| url | nil | URL override location used to specify custom HTTP source for the Optimizely datafile
| url_template | 'https://cdn.optimizely.com/datafiles/{sdk_key}.json' | Parameterized datafile URL by SDK key
| datafile | nil | Initial datafile, typically sourced from a local cached source
| auto_update | true | Boolean flag to specify if callback needs to execute infinitely or only once
| start_by_default | true | Boolean flag to specify if datafile polling should start right away as soon as `HTTPConfigManager` initializes
| blocking_timeout | 15 seconds | Maximum time in seconds to block the `config` call until config has been initialized

A notification signal will be triggered whenever a _new_ datafile is fetched and Project Config is updated. To subscribe to these notifications, use the
```ruby
notification_center.add_notification_listener(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE], @callback)
```


#### BatchEventProcessor

[BatchEventProcessor](https://github.com/optimizely/ruby-sdk/blob/master/lib/optimizely/event/batch_event_processor.rb) is a batched implementation of the [EventProcessor](https://github.com/optimizely/ruby-sdk/blob/master/lib/optimizely/event/event_processor.rb)

   * Events passed to the `BatchEventProcessor` are immediately added to a `Queue`.

   * The `BatchEventProcessor` maintains a single consumer thread that pulls events off of the `Queue` and buffers them for either a configured batch size or for a maximum duration before the resulting `LogEvent` is sent to the `NotificationCenter`.

#### Use BatchEventProcessor
```ruby
event_processor = Optimizely::BatchEventProcessor.new(
    event_queue: SizedQueue.new(10),
    event_dispatcher: event_dispatcher,
    batch_size: 10,
    flush_interval: 30000,
    logger: logger,
    notification_center: notification_center
)
```

#### Advanced configuration
The following properties can be used to customize the `BatchEventProcessor` configuration.

| **Property Name** | **Default Value** | **Description**
| -- | -- | --
| `event_queue` | 1000 | `SizedQueue.new(100)` or `Queue.new`. Queues individual events to be batched and dispatched by the executor. Default value is 1000.
| `event_dispatcher` | nil | Used to dispatch event payload to Optimizely. By default `EventDispatcher.new` will be set.
| `batch_size` | 10 | The maximum number of events to batch before dispatching. Once this number is reached, all queued events are flushed and sent to Optimizely.
| `flush_interval` | 30000 ms | Maximum time to wait before batching and dispatching events. In milliseconds.
| `notification_center` | nil | Notification center instance to be used to trigger any notifications.


#### Close Optimizely
If you enable event batching, make sure that you call the `close` method, `optimizely.close()`, prior to exiting. This ensures that queued events are flushed as soon as possible to avoid any data loss.

**Note:** Because the Optimizely client maintains a buffer of queued events, we recommend that you call `close()` on the Optimizely instance before shutting down your application or whenever dereferencing the instance.

| **Method** | **Description**
| -- | --
| `close()` | Stops all timers and flushes the event queue. This method will also stop any timers that are happening for the datafile manager.

For Further details see the Optimizely [Feature Experimentation documentation](https://docs.developers.optimizely.com/experimentation/v4.0.0-full-stack/docs/welcome)
to learn how to set up your first Ruby project and use the SDK.

## SDK Development

### Building the SDK

To build a local copy of the gem which will be output to `/pkg`:

```
rake build
```

### Unit Tests

#### Running all tests
You can run all unit tests with:

```
rake spec
```

### Contributing

Please see [CONTRIBUTING](CONTRIBUTING.md).

### Credits

This software incorporates code from the following open source projects:

**Httparty** [https://github.com/jnunemaker/httparty](https://github.com/jnunemaker/httparty)
Copyright &copy; 2008 John Nunemaker
License (MIT): [https://github.com/jnunemaker/httparty/blob/master/MIT-LICENSE](https://github.com/jnunemaker/httparty/blob/master/MIT-LICENSE)

**JSON Schema Validator** [https://github.com/ruby-json-schema/json-schema](https://github.com/ruby-json-schema/json-schema)
Copyright &copy; 2010-2011, Lookingglass Cyber Solutions
License (MIT): [https://github.com/ruby-json-schema/json-schema/blob/master/LICENSE.md](https://github.com/ruby-json-schema/json-schema/blob/master/LICENSE.md)

**Murmurhash3** [https://github.com/funny-falcon/murmurhash3-ruby](https://github.com/funny-falcon/murmurhash3-ruby)
Copyright &copy; 2012 Sokolov Yura 'funny-falcon'
License (MIT): [https://github.com/funny-falcon/murmurhash3-ruby/blob/master/LICENSE](https://github.com/funny-falcon/murmurhash3-ruby/blob/master/LICENSE)

### Additional Code

This software may be used with additional code that is separately downloaded by you.  _These components are subject to
their own license terms, which you should review carefully_.

**Bundler** [https://github.com/bundler/bundler](https://github.com/bundler/bundler)
Copyright &copy; 2008-2018 Andre Arko, Engine Yard, et al
License (MIT): [https://github.com/bundler/bundler/blob/master/LICENSE.md](https://github.com/bundler/bundler/blob/master/LICENSE.md)

**Coveralls** [https://github.com/lemurheavy/coveralls-ruby](https://github.com/lemurheavy/coveralls-ruby)
Copyright &copy; 2012 Wil Gieseler
License (MIT): [https://github.com/lemurheavy/coveralls-ruby/blob/master/LICENSE](https://github.com/lemurheavy/coveralls-ruby/blob/master/LICENSE)

**Rake** [https://github.com/ruby/rake](https://github.com/ruby/rake)
Copyright &copy; 2004-2017 Jim Weirich
License (MIT): [https://github.com/ruby/rake/blob/master/MIT-LICENSE](https://github.com/ruby/rake/blob/master/MIT-LICENSE)

**RSpec** [https://github.com/rspec/rspec](https://github.com/rspec/rspec)
Copyright &copy; 2009 Chad Humphries, David Chelimsky
Copyright &copy; 2006 David Chelimsky, The RSpec Development Team
Copyright &copy; 2005 Steven Baker
License (MIT): [https://github.com/rspec/rspec/blob/master/LICENSE.md](https://github.com/rspec/rspec/blob/master/LICENSE.md)

**RuboCop** [https://github.com/rubocop-hq/rubocop](https://github.com/rubocop-hq/rubocop)
Copyright &copy; 2012-19 Bozhidar Batsov
License (MIT): [https://github.com/rubocop-hq/rubocop/blob/master/LICENSE.txt](https://github.com/rubocop-hq/rubocop/blob/master/LICENSE.txt)

**WebMock** [https://github.com/bblimke/webmock](https://github.com/bblimke/webmock)
Copyright &copy; 2009-2010 Bartosz Blimke
License (MIT): [https://github.com/bblimke/webmock/blob/master/LICENSE](https://github.com/bblimke/webmock/blob/master/LICENSE)

### Other Optimizely SDKs

- Agent - https://github.com/optimizely/agent

- Android - https://github.com/optimizely/android-sdk

- C# - https://github.com/optimizely/csharp-sdk

- Flutter - https://github.com/optimizely/optimizely-flutter-sdk

- Go - https://github.com/optimizely/go-sdk

- Java - https://github.com/optimizely/java-sdk

- JavaScript - https://github.com/optimizely/javascript-sdk

- PHP - https://github.com/optimizely/php-sdk

- Python - https://github.com/optimizely/python-sdk

- React - https://github.com/optimizely/react-sdk

- Ruby - https://github.com/optimizely/ruby-sdk

- Swift - https://github.com/optimizely/swift-sdk
