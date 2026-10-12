# frozen_string_literal: true

module RecordingStudioEmbargo
  class Attributes
    KEYS = %i[enabled lifts_at time_zone early_access fallback].freeze

    def self.parse(parent_recording:, raw:)
      new(parent_recording, raw).parse
    end

    def initialize(parent_recording, raw)
      @parent_recording = parent_recording
      @raw = hashify(raw).symbolize_keys
    end

    def parse
      current = parent_recording.respond_to?(:current_embargo) ? parent_recording.current_embargo : nil
      merged = preserved(current)
      assign_provided(merged)
      merged[:lifts_at] = coerce_time(merged[:lifts_at], merged[:time_zone])
      merged
    end

    private

    attr_reader :parent_recording, :raw

    def preserved(current)
      {
        enabled: current&.enabled || false,
        lifts_at: current&.lifts_at,
        time_zone: current&.time_zone.presence || RecordingStudioEmbargo.configuration.default_time_zone,
        early_access: stringify_access(current&.early_access),
        fallback: current&.fallback
      }
    end

    def assign_provided(merged)
      assign_enabled(merged)
      assign_time_zone(merged)
      assign_fallback(merged)
      assign_early_access(merged)
      merged[:lifts_at] = raw[:lifts_at] if raw.key?(:lifts_at)
    end

    def assign_enabled(merged)
      merged[:enabled] = boolean_cast(raw[:enabled]) if raw.key?(:enabled)
    end

    def assign_time_zone(merged)
      return unless raw.key?(:time_zone)

      merged[:time_zone] = raw[:time_zone].presence || merged[:time_zone]
    end

    def assign_fallback(merged)
      merged[:fallback] = raw[:fallback].presence if raw.key?(:fallback)
    end

    def assign_early_access(merged)
      merged[:early_access] = stringify_access(raw[:early_access]) if raw.key?(:early_access)
    end

    def coerce_time(value, time_zone)
      return if value.blank?
      return value.utc if value.respond_to?(:utc) && !value.is_a?(String)

      parse_time(value, time_zone)
    end

    def parse_time(value, time_zone)
      return if value.blank?

      zone = ActiveSupport::TimeZone[time_zone.to_s] || ActiveSupport::TimeZone["UTC"]
      parsed = zone.parse(value.to_s)
      raise Invalid, Copy.t("errors.lifts_at_invalid") if parsed.blank? || shifted_wall_time?(parsed, value, zone)

      parsed.utc
    end

    def shifted_wall_time?(parsed, value, zone)
      text = value.to_s
      date = text[/\d{4}-\d{2}-\d{2}/]
      clock = text[/(\d{2}:\d{2})/, 1]
      return false if date.blank? || clock.blank?

      local = parsed.in_time_zone(zone)
      local.strftime("%Y-%m-%d") != date || local.strftime("%H:%M") != clock
    end

    def boolean_cast(value) # rubocop:disable Naming/PredicateMethod
      false_values = [false, nil, "", 0, "0", "false", "FALSE", "off", "f"]
      return false if false_values.include?(value)

      true
    end

    def stringify_access(value)
      hashify(value).each_with_object({}) do |(action, audience), result|
        action_name = action.to_s.strip
        audience_name = audience.to_s.strip
        next if action_name.empty? || audience_name.empty?

        result[action_name] = audience_name
      end
    end

    def hashify(value)
      return {} if value.blank?
      return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      return value.to_h if value.respond_to?(:to_h)

      {}
    rescue StandardError
      {}
    end
  end
end
