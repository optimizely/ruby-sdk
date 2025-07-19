require 'spec_helper'
require 'optimizely/decision_service'
require 'optimizely/logger'

describe 'CMAB DecisionService' do
  let(:logger) { Optimizely::SimpleLogger.new }
  let(:decision_service) { Optimizely::DecisionService.new(logger) }
  let(:experiment) do
    {
      'id' => '12345',
      'key' => 'cmab_experiment',
      'type' => 'cmab',
      'variations' => [
        { 'id' => 'v1', 'key' => 'variation_1' },
        { 'id' => 'v2', 'key' => 'variation_2' }
      ]
    }
  end
  let(:project_config) { double('ProjectConfig', get_experiment_from_id: experiment) }
  let(:user_context) { double('UserContext', user_id: 'user_abc', user_attributes: {}) }

  it 'returns a CMAB variation for a CMAB experiment' do
    variation_id, reasons = decision_service.get_variation(project_config, '12345', user_context)
    expect(['v1', 'v2']).to include(variation_id)
    expect(reasons.any? { |r| r.include?('CMAB decision') }).to be true
  end
end
