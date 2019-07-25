# Optimizely Ruby SDK
[![Build Status](https://travis-ci.org/optimizely/ruby-sdk.svg?branch=master)](https://travis-ci.org/optimizely/ruby-sdk)
[![Coverage Status](https://coveralls.io/repos/github/optimizely/ruby-sdk/badge.svg)](https://coveralls.io/github/optimizely/ruby-sdk)
[![Apache 2.0](https://img.shields.io/github/license/nebula-plugins/gradle-extra-configurations-plugin.svg)](http://www.apache.org/licenses/LICENSE-2.0)

This repository houses the Ruby SDK for use with Optimizely Full Stack and Optimizely Rollouts.

Optimizely Full Stack is A/B testing and feature flag management for product development teams. Experiment in any application. Make every feature on your roadmap an opportunity to learn. Learn more at https://www.optimizely.com/platform/full-stack/, or see the [documentation](https://docs.developers.optimizely.com/full-stack/docs).

Optimizely Rollouts is free feature flags for development teams. Easily roll out and roll back features in any application without code deploys. Mitigate risk for every feature on your roadmap. Learn more at https://www.optimizely.com/rollouts/, or see the [documentation](https://docs.developers.optimizely.com/rollouts/docs).

## Getting Started

### Installing the SDK

The SDK is available through [RubyGems](https://rubygems.org/gems/optimizely-sdk). To install:

```
gem install optimizely-sdk
```

### Feature Management Access
To access the Feature Management configuration in the Optimizely dashboard, please contact your Optimizely account executive.

### Using the SDK

You can initialize the Optimizely instance in two ways: directly with a datafile, or by using a factory class, `OptimizelyFactory`, which provides methods to create an Optimizely instance with the default configuration.

#### Initialization with datafile

 Initialize Optimizely with a datafile. This datafile will be used as ProjectConfig throughout the life of the Optimizely instance.

 ```
 optimizely_instance = Optimizely::Project.new(datafile)
 ```

#### Initialization by OptimizelyFactory

 1. Initialize Optimizely by providing an `sdk_key` and an optional `datafile`. This will initialize an HTTPConfigManager that makes an HTTP GET request to the URL (formed using your provided `sdk_key` and the default datafile CDN url template) to asynchronously download the project datafile at regular intervals and update ProjectConfig when a new datafile is recieved.

    ```
    optimizely_instance = Optimizely::OptimizelyFactory.default_instance('put_your_sdk_key_here', datafile)
    ```

   When the `datafile` is given then it will be used initially before any update.

 2. Initialize Optimizely by providing a Config Manager that implements a 'get_config' method. You can customize our `HTTPConfigManager` as needed.

    ```
    custom_config_manager = CustomConfigManager.new
    optimizely_instance = Optimizely::OptimizelyFactory.default_instance_with_config_manager(custom_config_manager)
    ```

 3. Initialize Optimizely with required `sdk_key` and other optional arguments.

      ```
       optimizely_instance = Optimizely::OptimizelyFactory.custom_instance(
          sdk_key,
          datafile,
          event_dispatcher,
          logger,
          error_handler,
          skip_json_validation,
          user_profile_service,
          config_manager,
          notification_center
      )
      ```   


#### HTTP Config Manager

The `HTTPConfigManager` asynchronously polls for datafiles from a specified URL at regular intervals by making HTTP requests.


~~~~~~
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
        notification_center: notification_center
      )
~~~~~~   
**Note:** You must provide either the `sdk_key` or URL. If you provide both, the URL takes precedence.

**sdk_key**
The `sdk_key` is used to compose the outbound HTTP request to the default datafile location on the Optimizely CDN.

**datafile**
You can provide an initial datafile to bootstrap the  `DataFileProjectConfig`  so that it can be used immediately. The initial datafile also serves as a fallback datafile if HTTP connection cannot be established. The initial datafile will be discarded after the first successful datafile poll.

**polling_interval**
The polling interval is used to specify a fixed delay between consecutive HTTP requests for the datafile. Between 1 to 2592000 seconds is valid duration. Otherwise default 5 minutes will be used.

**url_template**
A string with placeholder `{sdk_key}` can be provided so that this template along with the provided `sdk_key` is used to form the target URL.

**start_by_default**
Boolean flag used to start the `AsyncScheduler` for datafile polling if set to `True`.

**blocking_timeout**
The blocking timeout period is used to specify a maximum time to wait for initial bootstrapping.Between 1 to 2592000 seconds is valid blocking timeout period. Otherwise default value 15 seconds will be used.

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
| blocking_timeout | 15 seconds | Maximum time in seconds to block the `get_config` call until config has been initialized

A notification signal will be triggered whenever a _new_ datafile is fetched and Project Config is updated. To subscribe to these notifications, use the `notification_center.add_notification_listener(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE], @callback)`

See the Optimizely Full Stack [developer documentation](http://developers.optimizely.com/server/reference/index.html) to learn how to set up your first Full Stack project and use the SDK.

## Development

### Building the SDK

To build a local copy of the gem which will be output to `/pkg`:

```
rake build
```

### Unit tests

##### Running all tests
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
