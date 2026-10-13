# frozen_string_literal: true

module RecordingStudioEmbargo
  module Copy
    module_function

    def t(key, **)
      I18n.t("recording_studio_embargo.#{key}", **)
    end
  end
end
