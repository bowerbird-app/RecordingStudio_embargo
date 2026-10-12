# frozen_string_literal: true

module RecordingStudioEmbargo
  # Host action list. A symbol is just the key. A hash may add a label and description.
  module ActionCatalog
    module_function

    def normalize(actions)
      Array(actions).filter_map { |action| entry_for(action) }.uniq { |entry| key_of(entry) }
    end

    def definitions_for(actions)
      Array(actions).filter_map { |action| definition_for(action) }
    end

    def keys_for(actions)
      definitions_for(actions).map { |definition| definition[:action] }
    end

    def entry_for(action)
      return bare_entry(action) unless action.is_a?(Hash)

      labeled_entry(action)
    end

    def definition_for(action)
      return bare_definition(action) unless action.is_a?(Hash)

      labeled_definition(action)
    end

    def key_of(entry)
      entry.is_a?(Hash) ? entry[:action] : entry
    end

    def bare_entry(action)
      action.to_s.strip.presence&.to_sym
    end

    def labeled_entry(action)
      key = hash_key(action)
      return if key.blank?

      compact_entry(key, action)
    end

    def compact_entry(key, action)
      {
        action: key,
        label: text(action[:label] || action["label"]),
        description: text(action[:description] || action["description"])
      }.compact
    end

    def bare_definition(action)
      key = bare_entry(action)
      return if key.blank?

      { action: key, label: key.to_s, description: nil }
    end

    def labeled_definition(action)
      key = hash_key(action)
      return if key.blank?

      {
        action: key,
        label: text(action[:label] || action["label"]) || key.to_s,
        description: text(action[:description] || action["description"])
      }
    end

    def hash_key(action)
      raw = action[:action] || action["action"] || action[:key] || action["key"]
      raw.to_s.strip.presence&.to_sym
    end

    def text(value)
      value.to_s.strip.presence
    end
  end
end
