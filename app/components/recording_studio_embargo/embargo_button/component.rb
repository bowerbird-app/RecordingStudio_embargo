# frozen_string_literal: true

module RecordingStudioEmbargo
  module EmbargoButton
    class Component < ViewComponent::Base
      def initialize(recording:, turbo_frame: nil)
        super()
        @recording = recording
        @turbo_frame = turbo_frame.presence&.to_s
      end

      attr_reader :recording, :turbo_frame

      def self.wrapper_id(recording)
        "embargo_button_#{recording.id}"
      end

      def wrapper_id
        self.class.wrapper_id(recording)
      end

      def render?
        editable?
      end

      def active?
        return @active if defined?(@active)

        @active = recording&.current_embargo&.active? || false
      end

      def button_text
        Copy.t(active? ? "button.embargoed" : "button.add")
      end

      def button_style
        active? ? :warning : :secondary
      end

      def button_options
        options = { text: button_text, style: button_style, size: :md, href: edit_path }
        options[:icon] = "lock" if active?
        options[:data] = { turbo_frame: turbo_frame } if turbo_frame.present?
        options
      end

      def edit_path
        helpers.recording_studio_embargo.edit_recording_embargo_path(recording)
      end

      private

      def editable?
        manageable_recording? && allowed_to_edit?
      end

      def manageable_recording?
        recording.present? && capability_enabled?
      end

      def capability_enabled?
        return false unless defined?(RecordingStudio)

        RecordingStudio.capability_enabled?(:embargo, for: recording.recordable_type)
      end

      def allowed_to_edit?
        RecordingStudioEmbargo.configuration.authorize_management?(
          recording: recording,
          actor: current_actor,
          controller: helpers.controller
        )
      end

      def current_actor
        helpers.controller&.try(:current_user)
      end
    end
  end
end
