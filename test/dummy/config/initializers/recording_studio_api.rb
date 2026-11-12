# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.configure do |config|
  config.admin_root_recordable_type_names = [ "Workspace" ]
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
end

RecordingStudioApi.register_recordable_type_api(
  "Page",
  operations: %i[index show create update destroy],
  capability_actions: %i[set_embargo cancel_embargo show_embargo],
  serializer: ->(page, **) { { title: page.title } },
  output_keys: %i[title],
  writable_attributes: %i[title]
)
