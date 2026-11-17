# frozen_string_literal: true

require "test_helper"

class ManageGateTest < Minitest::Test
  def setup
    RecordingStudio::Gates.reset!
  end

  def teardown
    RecordingStudio::Gates.reset!
  end

  def test_manage_gate_name_and_default_allow
    assert_equal "embargo.manage", RecordingStudioEmbargo::MANAGE_GATE

    decision = RecordingStudioEmbargo.manage_decision(recording: recording, actor: actor)

    assert_instance_of RecordingStudio::GateDecision, decision
    assert decision.allowed?
    assert RecordingStudioEmbargo.manage_allowed?(recording: recording, actor: actor)
  end

  def test_a_denying_check_is_visible_to_both_helpers
    register_check { false }

    decision = RecordingStudioEmbargo.manage_decision(recording: recording, actor: actor, purpose: :menu)

    refute decision.allowed?
    refute RecordingStudioEmbargo.manage_allowed?(recording: recording, actor: actor)
    assert_equal "embargo.manage", decision.gate
  end

  def test_a_decision_keeps_the_redirect_and_reason
    register_check do
      RecordingStudio::GateDecision.deny(redirect_to: "/plans", reason: "plan")
    end

    decision = RecordingStudioEmbargo.manage_decision(recording: recording, actor: actor)

    refute decision.allowed?
    assert_equal "/plans", decision.redirect_to
    assert_equal "plan", decision.reason
  end

  def test_a_raised_check_denies
    register_check { raise "plan lookup failed" }

    decision = RecordingStudioEmbargo.manage_decision(recording: recording, actor: actor)

    refute decision.allowed?
    assert_nil decision.redirect_to
  end

  def test_extra_context_reaches_the_check
    seen = nil
    register_check do |actor:, recording:, **context|
      seen = [actor, recording, context[:purpose]]
      true
    end

    assert RecordingStudioEmbargo.manage_allowed?(recording: recording, actor: actor, purpose: :menu)
    assert_equal [actor, recording, :menu], seen
  end

  def test_reset_clears_a_denying_check
    register_check { false }
    RecordingStudio::Gates.reset!

    assert RecordingStudioEmbargo.manage_allowed?(recording: recording, actor: actor)
  end

  def test_can_manage_requires_the_role_and_the_gate
    authorizer = RecordingStudioEmbargo.configuration.management_authorizer
    RecordingStudioEmbargo.configuration.management_authorizer = ->(**) { true }

    assert RecordingStudioEmbargo.can_manage?(recording: recording, actor: actor)

    register_check { false }

    refute RecordingStudioEmbargo.manage_allowed?(recording: recording, actor: actor)
    refute RecordingStudioEmbargo.can_manage?(recording: recording, actor: actor)
  ensure
    RecordingStudioEmbargo.configuration.management_authorizer = authorizer
  end

  def test_can_manage_is_false_when_the_role_refuses
    authorizer = RecordingStudioEmbargo.configuration.management_authorizer
    RecordingStudioEmbargo.configuration.management_authorizer = ->(**) { false }

    assert RecordingStudioEmbargo.manage_allowed?(recording: recording, actor: actor)
    refute RecordingStudioEmbargo.can_manage?(recording: recording, actor: actor)
    refute RecordingStudioEmbargo.can_manage?(recording: recording, actor: nil)
  ensure
    RecordingStudioEmbargo.configuration.management_authorizer = authorizer
  end

  private

  def recording
    @recording ||= Object.new
  end

  def actor
    @actor ||= Object.new
  end

  def register_check(&)
    RecordingStudio.register_gate("embargo.manage", "host.plan", &)
  end
end
