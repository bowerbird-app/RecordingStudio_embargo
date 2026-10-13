# frozen_string_literal: true

module RecordingStudioEmbargo
  class Validator
    def self.call(parent_recording:, embargo:, attributes:)
      new(parent_recording, embargo, attributes).call
    end

    def initialize(_parent_recording, embargo, attributes)
      @embargo = embargo
      @attributes = attributes
    end

    def call
      embargo.apply_configuration!(@attributes)
      raise Invalid, embargo.errors.full_messages.to_sentence unless embargo.valid?
    end

    private

    attr_reader :embargo
  end
end
