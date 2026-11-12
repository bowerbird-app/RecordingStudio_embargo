# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.register_recordable_type_api(
  "Page",
  operations: %i[index show create update destroy],
  capability_actions: %i[set_embargo cancel_embargo show_embargo],
  serializer: ->(page, **) { { title: page.title } },
  output_keys: %i[title],
  writable_attributes: %i[title]
)
