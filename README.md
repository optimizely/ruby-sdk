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

