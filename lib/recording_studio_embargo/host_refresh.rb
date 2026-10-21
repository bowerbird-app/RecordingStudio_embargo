# frozen_string_literal: true

module RecordingStudioEmbargo
  # After an embargo change is durable, bust host fragment caches and ask open
  # pages that subscribe to the recording to render again.
  module HostRefresh
    module_function

    def after_commit(payload)
      recording = find_recording(payload)
      return if recording.blank?

      touch(recording)
      broadcast(recording)
    end

    def touch(recording)
      recording.touch if recording.respond_to?(:touch)
    end

    def broadcast(recording)
      return unless RecordingStudioEmbargo.configuration.broadcast_page_refresh

      channel = streams_channel
      return unless channel

      channel.broadcast_refresh_to(recording)
    rescue StandardError
      nil
    end

    def find_recording(payload)
      return unless defined?(RecordingStudio::Recording)
      return if payload.blank?

      id = payload[:recording_id] || payload["recording_id"]
      return if id.blank?

      RecordingStudio::Recording.find_by(id: id)
    end

    def streams_channel
      return unless defined?(Turbo::StreamsChannel)
      return unless Turbo::StreamsChannel.respond_to?(:broadcast_refresh_to)

      Turbo::StreamsChannel
    end
  end
end
