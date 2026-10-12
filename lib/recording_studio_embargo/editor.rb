# frozen_string_literal: true

module RecordingStudioEmbargo
  class Editor
    STATUS_STYLES = { "active" => :success, "expired" => :warning, "inactive" => :default }.freeze

    def initialize(recording:, embargo:)
      @recording = recording
      @embargo = embargo
    end

    attr_reader :recording, :embargo

    def status
      embargo.status_name
    end

    def status_style
      STATUS_STYLES.fetch(status, :default)
    end

    def status_label
      Copy.t("editor.status.#{status}")
    end

    def release_text
      return Copy.t("editor.release_missing") if embargo.lifts_at.blank?

      I18n.l(embargo.lifts_at.in_time_zone(embargo.effective_zone), format: :long)
    end

    def lifts_at_value
      return if embargo.lifts_at.blank?

      embargo.lifts_at.in_time_zone(embargo.effective_zone).strftime("%Y-%m-%dT%H:%M")
    end

    def time_zone_value
      zone = embargo.effective_zone
      friendly = ActiveSupport::TimeZone.all.find do |candidate|
        candidate.tzinfo.identifier == zone.tzinfo.identifier
      end
      friendly&.name || zone.name
    end

    def time_zone_options
      names = ActiveSupport::TimeZone.all.map(&:name)
      selected = time_zone_value
      names << selected if selected.present? && names.exclude?(selected)
      names.map { |name| zone_option(name) }
    end

    def actions
      RecordingStudioEmbargo.configuration.actions_for(recording)
    end

    def audience_fields
      RecordingStudioEmbargo.configuration.action_definitions_for(recording).map do |definition|
        audience_field(definition)
      end
    end

    def fallback_options
      RecordingStudioEmbargo.configuration.fallbacks_for(recording).map do |name|
        { label: name.to_s.humanize, value: name.to_s }
      end
    end

    def fallback_value
      embargo.fallback.presence || fallback_options.first&.dig(:value)
    end

    def enabled?
      embargo.enabled?
    end

    private

    def zone_option(name)
      zone = ActiveSupport::TimeZone[name]
      label = zone ? "(UTC#{zone.formatted_offset}) #{zone.name}" : name
      [label, zone&.name || name]
    end

    def audience_field(definition)
      action = definition[:action]
      {
        action: action,
        input_name: "embargo[early_access][#{action}]",
        label: definition[:label].presence || action.to_s,
        description: definition[:description].presence,
        value: embargo.early_access_for(action).presence || "granted",
        options: audience_options(action)
      }
    end

    def audience_options(action)
      return [] unless defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.audience_options_for(recording: recording, action: action).map do |option|
        { label: option[:label], value: option[:audience].to_s }
      end
    rescue StandardError
      []
    end
  end
end
