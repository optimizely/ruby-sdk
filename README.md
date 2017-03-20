# Optimizely Ruby SDK
[![Build Status](https://travis-ci.org/optimizely/ruby-sdk.svg?branch=master)](https://travis-ci.org/optimizely/ruby-sdk)
[![Coverage Status](https://coveralls.io/repos/github/optimizely/ruby-sdk/badge.svg)](https://coveralls.io/github/optimizely/ruby-sdk)
[![Apache 2.0](https://img.shields.io/github/license/nebula-plugins/gradle-extra-configurations-plugin.svg)](http://www.apache.org/licenses/LICENSE-2.0)

This repository houses the Ruby SDK for Optimizely's Full Stack product.

## Getting Started

### Installing the SDK

The SDK is available through [RubyGems](https://rubygems.org/gems/optimizely-sdk). To install:

```
gem install optimizely-sdk
```

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
