#Optimizely Ruby SDK

[![Build Status](https://travis-ci.com/optimizely/optimizely-testing-sdk-ruby.svg?token=xoLe5GgfDMgLPXDntAq3&branch=master)](https://travis-ci.com/optimizely/optimizely-testing-sdk-ruby)
[![Coverage Status](https://coveralls.io/repos/github/optimizely/optimizely-testing-sdk-ruby/badge.svg?branch=master&t=ZHDjST)](https://coveralls.io/github/optimizely/optimizely-testing-sdk-ruby?branch=master)

This repository houses the Ruby SDK for Optimizely's server-side testing product, which is currently in private beta.

##Getting Started

###Installing the SDK

The SDK is available through [RubyGems](https://rubygems.org/gems/optimizely-sdk). To install:

```
gem install optimizely-sdk
```

###Using the SDK
See the Optimizely server-side testing [developer documentation](http://developers.optimizely.com/server/reference/index) to learn how to set up your first custom project and use the SDK. **Please note that you must be a member of the private server-side testing beta to create custom projects and use this SDK.**

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
