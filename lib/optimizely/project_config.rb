# frozen_string_literal: true

#    Copyright 2016-2021, Optimizely and contributors
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
  class ProjectConfig
    # ProjectConfig is an interface capturing the experiment, variation and feature definitions.
    # The default implementation of ProjectConfig can be found in DatafileProjectConfig.

    def datafile; end

    def account_id; end

    def attributes; end

    def audiences; end

    def typed_audiences; end

    def events; end

    def experiments; end

    def feature_flags; end

    def groups; end

    def project_id; end

    def anonymize_ip; end

    def bot_filtering; end

    def revision; end

    def sdk_key; end

    def environment_key; end

    def send_flag_decisions; end

    def rollouts; end

    def integrations; end

    def public_key_for_odp; end

    def host_for_odp; end

    def experiment_running?(experiment); end

    def get_experiment_from_key(experiment_key); end

    def get_experiment_from_id(experiment_id); end

    def get_experiment_key(experiment_id); end

    def get_event_from_key(event_key); end

    def get_audience_from_id(audience_id); end

    def get_variation_from_id(experiment_key, variation_id); end

    def get_variation_from_id_by_experiment_id(experiment_id, variation_id); end

    def get_variation_id_from_key_by_experiment_id(experiment_id, variation_key); end

    def get_variation_id_from_key(experiment_key, variation_key); end

    def get_whitelisted_variations(experiment_id); end

    def get_attribute_id(attribute_key); end

    def variation_id_exists?(experiment_id, variation_id); end

    def get_feature_flag_from_key(feature_flag_key); end

    def get_feature_variable(feature_flag, variable_key); end

    def get_rollout_from_id(rollout_id); end

    def feature_experiment?(experiment_id); end
  end
end
