# frozen_string_literal: true

#
#    Copyright 2016-2020, 2022-2023, Optimizely and contributors
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module Optimizely
  class Error < StandardError; end

  class HTTPCallError < Error
    # Raised when a 4xx or 5xx response code is recieved.
    def initialize(msg = 'HTTP call resulted in a response with an error code.')
      super
    end
  end

  class HTTPUriError < Error
    # Raised when a provided URI is invalid.
    def initialize(msg = 'Provided URI was invalid.')
      super
    end
  end

  class MissingSdkKeyError < Error
    # Raised when a provided URI is invalid.
    def initialize(msg = 'SDK key not provided/cannot be found in the datafile.')
      super
    end
  end

  class InvalidAudienceError < Error
    # Raised when an invalid audience is provided

    attr_reader :audience_id

    def initialize(audience_id)
      raise ArgumentError, 'audience_id must be provided' if audience_id.nil?

      super("Audience id '#{audience_id}' is not in datafile.")

      @audience_id = audience_id
    end
  end

  class InvalidAttributeError < Error
    # Raised when an invalid attribute is provided

    attr_reader :attribute_key

    def initialize(attribute_key)
      raise ArgumentError, 'attribute_key must be provided' if attribute_key.nil?

      super("Attribute key '#{attribute_key}' is not in datafile.")

      @attribute_key = attribute_key
    end
  end

  class InvalidAttributeFormatError < Error
    # Raised when attributes are provided in an invalid format (e.g. not a Hash)

    def initialize(msg = 'Attributes provided are in an invalid format.')
      super
    end
  end

  class InvalidEventTagFormatError < Error
    # Raised when attributes are provided in an invalid format (e.g. not a Hash)

    def initialize(msg = 'Event tags provided are in an invalid format.')
      super
    end
  end

  class InvalidExperimentError < Error
    # Raised when an invalid experiment key is provided

    attr_reader :experiment_id, :experiment_key

    def initialize(experiment_id: nil, experiment_key: nil)
      raise ArgumentError, 'Either experiment_id or experiment_key must be provided.' if experiment_id.nil? && experiment_key.nil?
      raise ArgumentError, 'Cannot provide both experiment_id and experiment_key.' if !experiment_id.nil? && !experiment_key.nil?

      if experiment_id.nil?
        @experiment_key = experiment_key
        indentifier = "key '#{@experiment_key}'"
      else
        @experiment_id = experiment_id
        indentifier = "id '#{@experiment_id}'"
      end

      super("Experiment #{indentifier} is not in datafile.")
    end
  end

  class InvalidEventError < Error
    # Raised when an invalid event key is provided

    attr_reader :event_key

    def initialize(event_key)
      raise ArgumentError, 'event_key must be provided.' if event_key.nil?

      super("Event key '#{event_key}' is not in datafile.")

      @event_key = event_key
    end
  end

  class InvalidVariationError < Error
    # Raised when an invalid variation key or ID is provided

    attr_reader :variation_id, :variation_key

    def initialize(variation_id: nil, variation_key: nil)
      raise ArgumentError, 'Either variation_id or variation_key must be provided.' if variation_id.nil? && variation_key.nil?
      raise ArgumentError, 'Cannot provide both variation_id and variation_key.' if !variation_id.nil? && !variation_key.nil?

      if variation_id.nil?
        indentifier = "key '#{variation_key}'"
        @variation_key = variation_key
      else
        indentifier = "id '#{variation_id}'"
        @variation_id = variation_id
      end

      super("Variation #{indentifier} is not in datafile.")
    end
  end

  class InvalidDatafileVersionError < Error
    # Raised when a datafile with an unsupported version is provided

    def initialize(version)
      super("This version of the Ruby SDK does not support the given datafile version: #{version}.")
    end
  end

  class InvalidInputError < Error
    # Abstract error raised when an invalid input is provided during Project instantiation

    def initialize(type)
      super("Provided #{type} is in an invalid format.")
    end
  end

  class InvalidNotificationType < Error
    # Raised when an invalid notification type is provided

    def initialize(msg = 'Provided notification type is invalid.')
      super
    end
  end

  class InvalidInputsError < Error
    # Raised when an invalid inputs are provided during Project instantiation
  end

  class InvalidProjectConfigError < Error
    # Raised when a public method fails due to an invalid datafile

    def initialize(aborted_method)
      super("Optimizely instance is not valid. Failing '#{aborted_method}'.")
    end
  end

  class InvalidAttributeType < Error
    # Raised when an attribute is not provided in expected type.

    def initialize(msg = 'Provided attribute value is not in the expected data type.')
      super
    end
  end

  class InvalidSemanticVersion < Error
    # Raised when an invalid value is provided as semantic version.

    def initialize(msg = 'Provided semantic version is invalid.')
      super
    end
  end
end
