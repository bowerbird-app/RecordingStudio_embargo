# frozen_string_literal: true

require "test_helper"

class HostRefreshTest < Minitest::Test
  FakeRecording = Struct.new(:touched) do
    def touch
      self.touched = true
    end
  end

  def setup
    @configuration = RecordingStudioEmbargo.configuration
    @original_broadcast = @configuration.broadcast_page_refresh
  end

  def teardown
    @configuration.broadcast_page_refresh = @original_broadcast
  end

  def test_a_change_touches_the_recording_and_broadcasts_when_turbo_is_present
    recording = FakeRecording.new(false)
    sent = []
    channel = channel_for(sent)

    RecordingStudioEmbargo::HostRefresh.stub(:find_recording, recording) do
      RecordingStudioEmbargo::HostRefresh.stub(:streams_channel, channel) do
        RecordingStudioEmbargo::HostRefresh.after_commit({ recording_id: "parent" })
      end
    end

    assert recording.touched
    assert_equal [recording], sent
  end

  def test_broadcast_can_be_turned_off_without_skipping_the_touch
    @configuration.broadcast_page_refresh = false
    recording = FakeRecording.new(false)
    sent = []

    RecordingStudioEmbargo::HostRefresh.stub(:find_recording, recording) do
      RecordingStudioEmbargo::HostRefresh.stub(:streams_channel, channel_for(sent)) do
        RecordingStudioEmbargo::HostRefresh.after_commit({ recording_id: "parent" })
      end
    end

    assert recording.touched
    assert_empty sent
  end

  def test_broadcast_is_safe_when_turbo_is_not_loaded
    recording = FakeRecording.new(false)
    hide_turbo do
      assert_nil RecordingStudioEmbargo::HostRefresh.broadcast(recording)
    end
    refute recording.touched
  end

  def test_embargoed_is_an_active_hold_that_has_not_lifted
    active = Struct.new(:flag) { def embargo_active? = flag }.new(true)
    waiting = Struct.new(:flag) { def embargo_active? = flag }.new(false)

    assert RecordingStudioEmbargo.embargoed?(active)
    refute RecordingStudioEmbargo.embargoed?(waiting)
    refute RecordingStudioEmbargo.embargoed?(Object.new)
    refute RecordingStudioEmbargo.embargoed?(nil)
  end

  private

  def channel_for(sent)
    channel = Object.new
    channel.define_singleton_method(:broadcast_refresh_to) { |target| sent << target }
    channel
  end

  def hide_turbo
    return yield unless defined?(Turbo)

    hidden = Turbo
    Object.send(:remove_const, :Turbo)
    yield
  ensure
    Object.const_set(:Turbo, hidden) if hidden && !defined?(Turbo)
  end
end
