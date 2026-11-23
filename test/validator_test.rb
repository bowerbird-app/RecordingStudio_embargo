# frozen_string_literal: true

require "test_helper"
require "active_model"

class ValidatorTest < Minitest::Test
  def setup
    I18n.load_path << File.expand_path("../config/locales/en.yml", __dir__)
    I18n.backend.reload!
  end

  class FakeEmbargo
    extend ActiveModel::Naming

    def initialize
      @errors = ActiveModel::Errors.new(self)
    end

    attr_reader :errors

    def apply_configuration!(_attributes)
      errors.add(:lifts_at, RecordingStudioEmbargo::Copy.t("errors.lifts_at_future"))
    end

    def valid?
      false
    end

    def self.human_attribute_name(attr, _options = {})
      attr.to_s.humanize
    end

    def read_attribute_for_validation(_attr); end
  end

  def test_invalid_uses_messages_without_attribute_names
    error = assert_raises(RecordingStudioEmbargo::Invalid) do
      RecordingStudioEmbargo::Validator.call(
        parent_recording: nil,
        embargo: FakeEmbargo.new,
        attributes: {}
      )
    end

    assert_equal "The release time must be in the future.", error.message
    refute_includes error.message, "Lifts at"
  end
end
