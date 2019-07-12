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

To use the SDK, the Optimizely instance can be initialized in three different ways as per your requirement. Ruby SDK also includes a factory class, OptimizelyFactory, which provides methods to create Optimizely instance with default configuration.

 1. Initialize Optimizely with a datafile. This datafile will be used as ProjectConfig throughout the life of Optimizely instance.
    ~~~~~~~~~~~~
    optimizely_instance = Optimizely::Project.new(datafile)
2. Initialize Optimizely by providing an 'sdk_key'. This will initialize an HTTPConfigManager that makes an HTTP GET request to the URL ( formed using your provided sdk key and the default datafile CDN url template) to asynchronously download the project datafile at regular intervals and update ProjectConfig when a new datafile is recieved. 
      ~~~~~~~~~~~~
      optimizely_instance = Optimizely::OptimizelyFactory.create_default_instance_with_sdk_key('put_your_sdk_key_here')

  The OptimizelyFactory class also exposes method to initialize Optimizely instance with sdk_key along with a default datafile. This hard-coded datafile will be used initially before any update.
    
    
    optimizely_instance = Optimizely::OptimizelyFactory.create_default_instance_with_sdk_key_and_datafile('put_your_sdk_key_here', datafile)
   
 3. Initialize Optimizely by providing a Config Manager that implements a 'get_config' method.You may use our HTTP Config Manager and customize it to your need. 
    ~~~~~~~~~~~~
    custom_config_manager = CustomConfigManager.new
    optimizely_instance = Optimizely::OptimizelyFactory.create_default_instance_with_config_manager(custom_config_manager)


#### HTTP Config Manager

The HTTPConfigManager asynchronously polls for datafiles from a specified URL at regular intervals by making HTTP request.


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
**Note**: One of the sdk_key or url must be provided. When both are provided, url takes the preference.

**sdk_key**
The sdk_key is used to compose the outbound HTTP request to the default datafile location on the Optimizely CDN.

**datafile**
You can provide an initial datafile to bootstrap the  `DataFileProjectCongig`  so that it can be used immediately. The initial datafile also serves as a fallback datafile if HTTP connection cannot be established. The initial datafile will be discarded after the first successful datafile poll.

**polling_interval**
The polling_interval is used to specify a fixed delay in seconds between consecutive HTTP requests for the datafile.

**url_template**
A string with placeholder `{sdk_key}` can be provided so that this template along with the provided sdk key is used to form the target URL.

**start_by_default**
Boolean flag used to start the AsyncScheduler for datafile polling if set to True.

**blocking_timeout**
Maximum time in seconds to block the get_config call until config has been initialized.

You may also provide your own logger, error handler or notification center. 


#### Advanced configuration
The following properties can be set to override the default configurations for HTTPConfigManager.

| **PropertyName** | **Default Value** | **Description**
| -- | -- | --
| update_interval | 5 minutes | Fixed delay between fetches for the datafile 
| sdk_key | nil | Optimizely project SDK key
| url | nil | URL override location used to specify custom HTTP source for the Optimizely datafile. 
| url_template | 'https://cdn.optimizely.com/datafiles/{sdk_key}.json' | Parameterized datafile URL by SDK key.
| datafile | nil | Initial datafile, typically sourced from a local cached source.
| auto_update | true | Boolean flag to specify if callback needs to execute infinitely or once only.
| start_by_default | true | Boolean flag to specify if datafile polling should start right away as soon as the HTTPConfigManager initializes
| blocking_timeout | 15 seconds | Maximum time in seconds to block the get_config call until config has been initialized.

A notification signal will be triggered whenever a _new_ datafile is fetched and Project Config is updated. To subscribe to these notifications you can use the `notification_center.add_notification_listener(Optimizely::NotificationCenter::NOTIFICATION_TYPES[:OPTIMIZELY_CONFIG_UPDATE], @callback)`

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
