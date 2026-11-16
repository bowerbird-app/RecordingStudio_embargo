# frozen_string_literal: true

module RecordingStudioEmbargo
  LifecycleSnapshot = Data.define(
    :embargo_id, :enabled, :lifts_at, :time_zone, :accepts_early_access_requests, :fingerprint
  ) do
    def to_payload
      {
        enabled: enabled,
        lifts_at: lifts_at,
        time_zone: time_zone,
        accepts_early_access_requests: accepts_early_access_requests
      }
    end
  end
end
