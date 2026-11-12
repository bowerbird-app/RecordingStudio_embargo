# frozen_string_literal: true

module RecordingStudioEmbargo
  module Api
    ACTIONS = [
      {
        name: :set_embargo,
        handler: SetEmbargo,
        http_verb: :post,
        input_fields: {
          enabled: { type: :boolean },
          lifts_at: { type: :string, allow_blank: true },
          time_zone: { type: :string, allow_blank: true },
          early_access: { type: :boolean }
        },
        openapi: {
          summary: "Set or update the embargo on this recording.",
          description: "Writes the embargo through embargo_set!.",
          responses: {
            "200" => { description: "Embargo was written." },
            "403" => { description: "The access grant cannot manage this embargo." },
            "404" => { description: "The recording is outside this grant." },
            "422" => { description: "The embargo attributes are invalid." }
          }
        }
      },
      {
        name: :cancel_embargo,
        handler: CancelEmbargo,
        http_verb: :post,
        input_fields: {},
        openapi: {
          summary: "Cancel the embargo on this recording.",
          description: "Clears the hold through embargo_cancel!.",
          responses: {
            "200" => { description: "Embargo was cancelled." },
            "403" => { description: "The access grant cannot manage this embargo." },
            "404" => { description: "The recording is outside this grant." }
          }
        }
      },
      {
        name: :show_embargo,
        handler: ShowEmbargo,
        http_verb: :get,
        input_fields: {},
        openapi: {
          summary: "Read the current embargo on this recording.",
          description: "Returns current_embargo fields and embargo_active?.",
          responses: {
            "200" => { description: "Current embargo was returned." },
            "403" => { description: "The access grant cannot manage this embargo." },
            "404" => { description: "The recording is outside this grant." }
          }
        }
      }
    ].freeze
  end
end
