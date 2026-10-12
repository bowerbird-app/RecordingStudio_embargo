# frozen_string_literal: true

require "recording_studio"
require "recording_studio_embargo/version"
require "recording_studio_embargo/errors"
require "recording_studio_embargo/copy"
require "recording_studio_embargo/action_catalog"
require "recording_studio_embargo/configuration"
require "recording_studio_embargo/copy_policy"
require "recording_studio_embargo/attributes"
require "recording_studio_embargo/validator"
require "recording_studio_embargo/restriction"
require "recording_studio_embargo/composition"
require "recording_studio_embargo/cache"
require "recording_studio_embargo/editor"
require "recording_studio_embargo/recording_extensions"
require "recording_studio_embargo/lifecycle"
require "recording_studio_embargo/services/embargoes/upsert"
require "recording_studio_embargo/services/embargoes/cancel"
require "recording_studio/capabilities/embargo"
require "recording_studio_embargo/engine"

module RecordingStudioEmbargo
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def install!
      return unless defined?(RecordingStudio)

      RecordingStudio.apply_capabilities! if RecordingStudio.respond_to?(:apply_capabilities!)
      RecordingStudio::Capabilities::Embargo.ensure_child_recordable_registered!
    end

    def subscribe(name, &)
      Lifecycle.subscribe(name, &)
    end

    def restriction_for(...)
      Restriction.for(...)
    end

    def action_permitted?(...)
      Composition.action_permitted?(...)
    end

    def presskit_presentation(...)
      Composition.presskit_presentation(...)
    end

    def cache_key(...)
      Cache.key(...)
    end

    def cache_expires_in(...)
      Cache.expires_in(...)
    end

    def attributes_for_duplicate(embargo = nil)
      CopyPolicy.attributes_for_duplicate(embargo)
    end

    def observe_lift!(recording)
      embargo = recording&.current_embargo
      return if embargo&.lifts_at.blank?

      Lifecycle.emit_lift_if_due!(
        parent_recording_id: recording.id,
        expected_lifts_at: embargo.lifts_at
      )
    end
  end
end
