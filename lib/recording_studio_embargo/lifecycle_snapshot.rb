# frozen_string_literal: true

module RecordingStudioEmbargo
  LifecycleSnapshot = Data.define(
    :embargo_id, :enabled, :lifts_at, :time_zone, :early_access, :fingerprint
  ) do
    def to_payload
      {
        enabled: enabled,
        lifts_at: lifts_at,
        time_zone: time_zone,
        early_access: early_access
      }
    end
  end
end
