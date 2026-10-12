# frozen_string_literal: true

module RecordingStudioEmbargo
  # Recording copies must not inherit an active window or early-access list.
  # `revise` still duplicates the recordable so history stays intact. Hosts
  # that duplicate a parent recording into a new recording apply this hash
  # instead of copying the source embargo attributes.
  module CopyPolicy
    CLEARED = {
      enabled: false,
      lifts_at: nil,
      early_access: {},
      fallback: nil
    }.freeze

    module_function

    def attributes_for_duplicate(_embargo = nil)
      CLEARED.merge(early_access: {})
    end
  end
end
