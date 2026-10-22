# RecordingStudio Embargo

Recording Studio capability that holds listed actions until a release time. Early access is one switch for people who already have access. Embargo does not publish, grant access, or build downloads.

## What it decides

`RecordingStudioEmbargo.restriction_for(recording:, action:, actor:)` returns:

- `:not_applicable` when the embargo is off, the action is not one the host listed, or `Time.current` is at or after `lifts_at`
- `:allow` when early access is on and the actor satisfies Accessible's `:granted` audience for that action
- `:deny` otherwise, including when the baseline audience is `:public` and when early access is off

`:allow` does not authorize the action. Hosts still enforce publication, the baseline audience, and domain rules. `:deny` does restrict the action. A public baseline is not combined with early access, because a public audience is true for every actor and would skip the embargo.

```ruby
RecordingStudioEmbargo.action_permitted?(recording:, action:, actor:)
RecordingStudioEmbargo.presskit_presentation(recording:, actor:, view_action:)
```

`action_permitted?` is false when Publishable says the recording is not currently published, when the embargo denies the actor, or when the baseline audience denies the actor. `presskit_presentation` keeps the Presskits order: unpublished stays `:unavailable` (editors with view access still get `:full`). An embargo denial uses the fallback the host passes in, which is the host's own preview or hidden setting.

Expiry is read at authorization time. `LiftTransitionJob` only emits `:embargo_lifted`, and it no-ops unless the stored `lifts_at` still matches the scheduled instant.

## Opt in

```ruby
class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false
  include RecordingStudio::Capabilities::Embargo.to(
    actions: [ :"pages.show", :"pages.download" ],
    manage_role: :edit
  )
end
```

Configure those same actions on Accessible before enabling an embargo. Early access uses each action's granted roles, so a view grant does not include download. Copying a recording must call `RecordingStudioEmbargo.attributes_for_duplicate`, which clears the window and turns early access off.

The editor at `/recording_studio_embargo/recordings/:id/embargo/edit` is an enable switch, a release time, a time zone, and one early-access switch. Release date and time zone sit side by side and stack on a small screen. On a wide screen the editor stops at a medium width and stays full width below that. The explanation collapse sits below the form with space above it. Preview and hidden stay on the host. Default English copy lives in `config/locales/en.yml` under `recording_studio_embargo.editor`. The subtitle names the recordable in lowercase (`model_name.human.downcase`) and asks for a release date. A collapse under the form, "What is an embargo", holds the longer explanation. The submit button reads "Update". A host overrides `subtitle`, `explanation`, `enable_help`, and `early_access_help` in its own locale file. The editor does not hardcode a recordable name or press kit actions.

## Host link

Include `RecordingStudioEmbargo::ApplicationHelper` (the engine does this for host views). Link to the editor with the recording the host already has. Embargo does not ask the host for an embargo id, and it does not render the host's menu.

```erb
<%= recording_studio_embargo_management_path(page_recording, return_to: request.fullpath) %>
```

`return_to:` is optional. After a full-page save, Embargo redirects there when the value is a same-origin path. Anything else is ignored, and the editor is shown again.

`embargoed?(page_recording)` is true only while a hold is on and the release time is still ahead. Use it for a lock or a label. `RecordingStudioEmbargo.embargoed?(recording)` is the same check outside a view.

## Host notice

`render_embargo_notice` is static copy. It is not an alert. It renders nothing when there is no embargo, the embargo is off, or the release time has passed. Anyone who can open the page sees it while the embargo is active, including people who cannot edit it.

```erb
<%= render_embargo_notice(page_recording) %>
<%= render_embargo_notice(page_recording, size: :sm, class: "mt-2", id: "page-embargo") %>
```

The card is `FlatPack::Card` with `style: :default`, `border: :strong` (a 2px outline), and `shadow: :none`. No card style is plain white, so the notice adds `!bg-white`. The important modifier is required: the default fill is a later `background` shorthand, and a plain `bg-white` loses to it. Corners stay rounded. The space inside is one and a half times the compact card padding, at both sizes. The card is as wide as its words. Inside, a lock sits on the left of a bold title and a muted line. `size:` is `:md` by default, or `:sm` where space is tight. `class:` and `id:` pass through to the card.

The title reads "Embargoed until 12 Mar 2026, 9:00 AM AEDT". The time is `lifts_at` in the embargo's own time zone, with the zone abbreviation. The line under it reads "Not for publication until embargo lifts." Override `recording_studio_embargo.notice.title`, `recording_studio_embargo.notice.subtitle`, and `recording_studio_embargo.notice.time_format`. This needs Flatpack `v0.1.237` or newer, so the card accepts `border:` and `shadow:`.

## Page or modal

The editor is one view. A normal visit renders the full page. A request with a `Turbo-Frame` header renders that same editor with no page layout, inside the frame the host named. This gem does not render a modal and does not know the host's modal id or frame name.

A Flatpack menu item is enough. The ids below belong to the host:

```erb
<%= turbo_stream_from page_recording %>

<%= render FlatPack::Modal::Component.new(id: "embargo-editor-modal", size: :xl) do |modal| %>
  <% modal.body do %>
    <%= turbo_frame_tag "embargo_editor" %>
  <% end %>
<% end %>

<%= render FlatPack::Button::Dropdown::Component.new(text: "More") do |dropdown| %>
  <% dropdown.menu_item(
    text: embargoed?(page_recording) ? "Embargoed" : "Embargo",
    icon: ("lock" if embargoed?(page_recording)),
    href: recording_studio_embargo_management_path(page_recording, return_to: request.fullpath),
    data: { modal_id: "embargo-editor-modal", turbo_frame: "embargo_editor" }
  ) %>
<% end %>
```

Leave the frame data off the link and it opens the editor as a page. Saving on that page redirects to `return_to`, or back to the editor when `return_to` is missing or not same-origin. Saving inside a frame responds with `turbo_stream.refresh` (`method="morph"`) so the host page renders again. Embargo does not replace the host's markup. A validation error is shown in the same frame.

`turbo_stream_from page_recording` is optional. When `config.broadcast_page_refresh` is true (the default) and turbo-rails is loaded, a create, update, cancel, or scheduled lift broadcasts a page refresh on that stream. Set `config.broadcast_page_refresh = false` to keep the notifications and skip the broadcast. The call is skipped when turbo-rails is not loaded.

Any of those changes also touches the parent recording, so a fragment cache keyed on that recording rebuilds. `render_embargo_notice` is unchanged.

## Host follow-ups

Publishable needs no code change. Downloadable and Presskits do. The exact call sites are in [`docs/integration_plan.md`](docs/integration_plan.md).

## Install

```bash
bundle add recording_studio_embargo
bin/rails generate recording_studio_embargo:install
bin/rails generate recording_studio_embargo:migrations
bin/rails db:migrate
```

Migration details are in [`MIGRATION_NOTES.md`](MIGRATION_NOTES.md).

## Dummy app

The dummy app pins Recording Studio dummy GitHub tag `v4.5.0`, Accessible dummy GitHub tag `v0.15.0`, Root Switchable dummy GitHub tag `v0.8.0`, and FlatPack dummy GitHub tag `v0.1.240`. The home page shows the embargo notice at the default size and at `:sm` for the seeded page. A More menu opens the editor in a host modal. "Open embargo page" opens the same editor as a page.

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Sign in as `admin@admin.com` / `Password`. The home page opens the embargo editor for the seeded page inside a Flatpack modal. `/recording_studio` redirects to `/`.

Authenticated pages use Recording Studio's default layout. Devise keeps its own sign-in layout.
