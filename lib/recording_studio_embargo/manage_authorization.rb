# frozen_string_literal: true

module RecordingStudioEmbargo
  class ManageAuthorization
    def initialize(recording:, actor:, controller:)
      @recording = recording
      @actor = actor
      @controller = controller
    end

    def allowed?
      management_allowed? && manage_decision.allowed?
    end

    def management_allowed?
      configuration.authorize_management?(recording: recording, actor: actor, controller: controller)
    end

    def redirect_path
      return if manage_decision.allowed?

      ReturnTo.path(manage_decision.redirect_to, request: controller.request)
    end

    private

    attr_reader :recording, :actor, :controller

    def configuration
      RecordingStudioEmbargo.configuration
    end

    def manage_decision
      @manage_decision ||= RecordingStudioEmbargo.manage_decision(recording: recording, actor: actor)
    end
  end
end
