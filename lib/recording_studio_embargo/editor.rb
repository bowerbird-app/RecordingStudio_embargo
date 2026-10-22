# frozen_string_literal: true

module RecordingStudioEmbargo
  class Editor
    def initialize(recording:, embargo:)
      @recording = recording
      @embargo = embargo
    end

    attr_reader :recording, :embargo

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

    def enabled?
      embargo.enabled?
    end

    def early_access?
      embargo.early_access?
    end

    private

    def zone_option(name)
      zone = ActiveSupport::TimeZone[name]
      label = zone ? "(UTC#{zone.formatted_offset}) #{zone.name}" : name
      [label, zone&.name || name]
    end
  end
end
