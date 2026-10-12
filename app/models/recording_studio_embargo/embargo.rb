# frozen_string_literal: true

module RecordingStudioEmbargo
  class Embargo < ApplicationRecord
    self.table_name = "recording_studio_embargo_embargoes"

    if respond_to?(:recording_studio_recordable)
      recording_studio_recordable label: "Embargo", plural_label: "Embargoes", root: false
    end

    validates :time_zone, presence: true
    validate :time_zone_is_known
    validate :lifts_at_is_usable
    validate :early_access_is_a_map

    def active?(at = Time.current)
      enabled? && lifts_at.present? && lifts_at > at
    end

    def expired?(at = Time.current)
      enabled? && lifts_at.present? && lifts_at <= at
    end

    def status_name(at = Time.current)
      return "active" if active?(at)
      return "expired" if expired?(at)

      "inactive"
    end

    def early_access_for(action)
      early_access.to_h[action.to_s].presence
    end

    def apply_configuration!(attrs)
      self.enabled = attrs.fetch(:enabled)
      self.lifts_at = attrs[:lifts_at]
      self.time_zone = attrs[:time_zone].presence || "UTC"
      self.early_access = attrs[:early_access].to_h
      self.fallback = attrs[:fallback].presence
    end

    def effective_zone
      ActiveSupport::TimeZone[time_zone] || ActiveSupport::TimeZone["UTC"]
    end

    private

    def time_zone_is_known
      return if time_zone.blank?
      return if ActiveSupport::TimeZone[time_zone]

      errors.add(:time_zone, Copy.t("errors.time_zone_invalid"))
    end

    def lifts_at_is_usable
      return unless enabled?

      require_release_fields
      require_future_release
    end

    def require_release_fields
      errors.add(:lifts_at, Copy.t("errors.lifts_at_required")) if lifts_at.blank?
      errors.add(:early_access, Copy.t("errors.early_access_required")) if early_access.blank?
    end

    def require_future_release
      return if lifts_at.blank? || lifts_at > Time.current

      errors.add(:lifts_at, Copy.t("errors.lifts_at_future"))
    end

    def early_access_is_a_map
      return if early_access.is_a?(Hash)

      errors.add(:early_access, Copy.t("errors.early_access_invalid"))
    end
  end
end
