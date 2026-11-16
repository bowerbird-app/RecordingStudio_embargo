RecordingStudio Embargo install

1. Mount is added at the path you passed (default `/recording_studio_embargo`).
2. Review `config/initializers/recording_studio_embargo.rb` for auth, layout, and current actor integration.
3. Declare the recordable with `recording_studio_recordable`, then opt it in:
   `include RecordingStudio::Capabilities::Embargo`.
4. Install migrations: `bin/rails generate recording_studio_embargo:migrations`
5. Migrate: `bin/rails db:migrate`
6. Rebuild Tailwind if the host renders the editor: `bin/rails tailwindcss:build`
7. Link to the editor from the host. The helper takes the recording the host already has:

```erb
<%= turbo_stream_from page_recording %>

<%= render FlatPack::Button::Dropdown::Component.new(text: "More") do |dropdown| %>
  <% dropdown.menu_item(
    text: embargoed?(page_recording) ? "Embargoed" : "Embargo",
    icon: ("lock" if embargoed?(page_recording)),
    href: recording_studio_embargo_management_path(page_recording, return_to: request.fullpath),
    data: { modal_id: "embargo-editor-modal", turbo_frame: "embargo_editor" }
  ) %>
<% end %>
```

The host owns the modal and the frame. Leave those data attributes off to open the editor as a page. `config.broadcast_page_refresh` (default true) refreshes pages subscribed with `turbo_stream_from` when an embargo changes or lifts. It does nothing when turbo-rails is not loaded.

This gem stores the embargo. Press Kits decides who can see the recording.
See `docs/integration_plan.md`.
