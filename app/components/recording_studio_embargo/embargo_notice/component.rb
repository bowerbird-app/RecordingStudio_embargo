# frozen_string_literal: true

module RecordingStudioEmbargo
  module EmbargoNotice
    class Component < ViewComponent::Base
      SIZES = %i[sm md].freeze

      def initialize(recording:, size: :md, **system_arguments)
        super()
        @recording = recording
        @size = size.to_sym
        @system_arguments = system_arguments
        validate_size!
      end

      attr_reader :recording, :size

      def render?
        active_embargo.present?
      end

      def title
        Copy.t("notice.title", time: formatted_lifts_at)
      end

      def subtitle
        Copy.t("notice.subtitle")
      end

      def compact?
        size == :sm
      end

      def card_options
        @system_arguments.except(:class, :style, :border, :shadow).merge(
          style: :default,
          border: :strong,
          shadow: :none,
          class: notice_classes
        )
      end

      def body_padding
        :sm
      end

      def icon_size
        compact? ? :sm : :lg
      end

      private

      def notice_classes
        ["w-fit max-w-full !bg-white", @system_arguments[:class]].compact_blank.join(" ")
      end

      def active_embargo
        return if recording.blank?
        return unless recording.respond_to?(:current_embargo)

        embargo = recording.current_embargo
        embargo if embargo&.active?
      end

      def formatted_lifts_at
        embargo = active_embargo
        zoned = embargo.lifts_at.in_time_zone(embargo.effective_zone)
        I18n.l(zoned, format: Copy.t("notice.time_format"))
      end

      def validate_size!
        return if SIZES.include?(size)

        raise ArgumentError, "Invalid size: #{size}. Must be one of: #{SIZES.join(', ')}"
      end
    end
  end
end
