# frozen_string_literal: true

module RecordingStudioEmbargo
  class Error < StandardError; end
  class Unauthorized < Error; end
  class Invalid < Error; end
end
