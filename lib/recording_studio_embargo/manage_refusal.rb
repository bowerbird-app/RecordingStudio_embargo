# frozen_string_literal: true

module RecordingStudioEmbargo
  module ManageRefusal
    private

    def raise_unless_manage_gate_allows!
      decision = RecordingStudioEmbargo.manage_decision(recording: parent_recording, actor: actor)
      return if decision.allowed?

      raise Unauthorized.from_decision(decision)
    end
  end
end
