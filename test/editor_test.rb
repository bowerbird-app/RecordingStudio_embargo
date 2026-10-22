# frozen_string_literal: true

require "test_helper"

class EditorTest < Minitest::Test
  def setup
    I18n.load_path << File.expand_path("../config/locales/en.yml", __dir__)
    I18n.backend.reload!
  end

  def test_recordable_name_downcases_the_human_model_name
    editor = editor_for(recordable: named("Press kit"), recordable_type: "RecordingStudio::PressKit")

    assert_equal "press kit", editor.recordable_name
  end

  def test_recordable_name_falls_back_to_the_type_when_the_recordable_has_no_model_name
    editor = editor_for(recordable: Object.new, recordable_type: "RecordingStudio::PressKit")

    assert_equal "press kit", editor.recordable_name
  end

  def test_editor_locale_uses_the_recordable_name_and_drops_the_fieldset
    editor = editor_for(recordable: named("Page"), recordable_type: "Page")
    subtitle = RecordingStudioEmbargo::Copy.t("editor.subtitle", recordable_name: editor.recordable_name)

    assert_equal "Embargo this page and set a release date.", subtitle
    assert_equal "Update", RecordingStudioEmbargo::Copy.t("editor.save")
    assert_equal "What is an embargo", RecordingStudioEmbargo::Copy.t("editor.what_is_an_embargo")
    assert_includes RecordingStudioEmbargo::Copy.t("editor.explanation"), "advance notice"
    refute I18n.exists?("recording_studio_embargo.editor.fieldset")
  end

  private

  def editor_for(recordable:, recordable_type:)
    recording = Struct.new(:recordable, :recordable_type).new(recordable, recordable_type)
    RecordingStudioEmbargo::Editor.new(recording: recording, embargo: nil)
  end

  def named(human_name)
    model_name = Struct.new(:human).new(human_name)
    Struct.new(:model_name).new(model_name)
  end
end
