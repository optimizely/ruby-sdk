#Optimizely Ruby SDK

This repository houses the Ruby SDK for Optimizely's Full Stack product.
[![Build Status](https://travis-ci.com/optimizely/optimizely-testing-sdk-ruby.svg?token=xoLe5GgfDMgLPXDntAq3&branch=master)](https://travis-ci.com/optimizely/optimizely-testing-sdk-ruby)
[![Coverage Status](https://coveralls.io/repos/github/optimizely/optimizely-testing-sdk-ruby/badge.svg?branch=master&t=ZHDjST)](https://coveralls.io/github/optimizely/optimizely-testing-sdk-ruby?branch=master)
[![Apache 2.0](https://img.shields.io/github/license/nebula-plugins/gradle-extra-configurations-plugin.svg)](http://www.apache.org/licenses/LICENSE-2.0)

##Getting Started

###Installing the SDK

The SDK is available through [RubyGems](https://rubygems.org/gems/optimizely-sdk). To install:

```
gem install optimizely-sdk
```

###Using the SDK
See the Optimizely Full Stack [developer documentation](http://developers.optimizely.com/server/reference/index.html) to learn how to set up your first Full Stack project and use the SDK.

##Development

###Building the SDK

To build a local copy of the gem which will be output to `/pkg`:

```
rake build
```

###Unit tests

#####Running all tests
You can run all unit tests with:

```
rake spec
```

###Contributing

Please see [CONTRIBUTING](CONTRIBUTING.md).
