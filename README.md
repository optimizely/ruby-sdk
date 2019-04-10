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
