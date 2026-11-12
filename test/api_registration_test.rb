# frozen_string_literal: true

require "test_helper"

class ApiRegistrationTest < Minitest::Test
  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudioEmbargo::Api.register_capability_actions!
  end
end
