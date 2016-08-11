module OptimizelyBenchmark
  TEST_DATA = {
    'test_activate' => {
      10 => 'test',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_activate_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'test'
    },
    'test_activate_with_forced_variation' => {
      10 => 'variation_user',
      25 => 'variation_user',
      50 => 'variation_user'
    },
    'test_activate_grouped_exp' => {
      10 => 'no',
      25 => 'test',
      50 => 'optimizely_user'
    },
    'test_activate_grouped_exp_with_attributes' => {
      10 => 'test',
      25 => 'yes',
      50 => 'test'
    },
    'test_get_variation' => {
      10 => 'test',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_get_variation_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'test'
    },
    'test_get_variation_with_forced_variation' => {
      10 => 'variation_user',
      25 => 'variation_user',
      50 => 'variation_user'
    },
    'test_get_variation_grouped_exp' => {
      10 => 'no',
      25 => 'test',
      50 => 'optimizely_user'
    },
    'test_get_variation_grouped_exp_with_attributes' => {
      10 => 'test',
      25 => 'yes',
      50 => 'test'
    },
    'test_track' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_with_revenue' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_with_attributes_and_revenue' => {
      10 => 'optimizely_user',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_grouped_exp' => {
      10 => 'no',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_grouped_exp_with_attributes' => {
      10 => 'optimizely_user',
      25 => 'yes',
      50 => 'test'
    },
    'test_track_grouped_exp_with_revenue' => {
      10 => 'no',
      25 => 'optimizely_user',
      50 => 'optimizely_user'
    },
    'test_track_grouped_exp_with_attributes_and_revenue' => {
      10 => 'optimizely_user',
      25 => 'yes',
      50 => 'test'
    },
  }
end
