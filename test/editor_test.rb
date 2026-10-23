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
    assert_equal [
      "An embargo lets you share your press kit with journalists before it's made public, giving them time to prepare their stories.",
      "Journalists who receive early access are expected to keep the information confidential and not publish anything until the embargo date and time.",
      "Embargoes work on an honour system. This tool helps you communicate the embargo and control who has early access, but it cannot prevent someone from sharing or publishing the information early.",
      "Only grant early access to people you trust."
    ], RecordingStudioEmbargo::Copy.t("editor.explanation_paragraphs")
    refute I18n.exists?("recording_studio_embargo.editor.explanation")
    refute I18n.exists?("recording_studio_embargo.editor.fieldset")
  end
end
