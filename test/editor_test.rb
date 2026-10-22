# frozen_string_literal: true

require "test_helper"

class EditorTest < Minitest::Test
  def setup
    I18n.load_path << File.expand_path("../config/locales/en.yml", __dir__)
    I18n.backend.reload!
  end

  def test_editor_subtitle_is_fixed_and_the_fieldset_key_is_gone
    assert_equal "Lock with embargo and set a release date", RecordingStudioEmbargo::Copy.t("editor.subtitle")
    assert_equal "Update", RecordingStudioEmbargo::Copy.t("editor.save")
    assert_equal "What is an embargo", RecordingStudioEmbargo::Copy.t("editor.what_is_an_embargo")
    assert_includes RecordingStudioEmbargo::Copy.t("editor.explanation"), "advance notice"
    refute I18n.exists?("recording_studio_embargo.editor.fieldset")
  end
end
