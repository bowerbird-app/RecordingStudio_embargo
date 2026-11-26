# frozen_string_literal: true

module RecordingStudioEmbargo
  class Error < StandardError; end

  class Unauthorized < Error
    def self.from_decision(decision)
      error = new(Copy.t("errors.unauthorized"))
      return error unless decision.code

      error.extend(RecordingStudio::Denial)
      error.denial(code: decision.code, details: decision.details)
    end
  end

  class Invalid < Error; end
end
