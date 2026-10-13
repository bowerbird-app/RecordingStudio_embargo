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

    def active?(at = Time.current)
      enabled? && lifts_at.present? && lifts_at > at
    end

    def apply_configuration!(attrs)
      self.enabled = attrs.fetch(:enabled)
      self.lifts_at = attrs[:lifts_at]
      self.time_zone = attrs[:time_zone].presence || "UTC"
      self.early_access = attrs[:early_access] ? true : false
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

      errors.add(:lifts_at, Copy.t("errors.lifts_at_required")) if lifts_at.blank?
      return if lifts_at.blank? || lifts_at > Time.current

      errors.add(:lifts_at, Copy.t("errors.lifts_at_future"))
    end
  end
end
