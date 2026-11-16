# RecordingStudio Embargo

Recording Studio capability that stores an embargo on a recording: whether it is on, when it lifts, the time zone, and whether people without access can ask for early access. It does not publish, grant access, decide who can see the recording, or build downloads. Press Kits owns visibility.

## What it stores

`recording.current_embargo` is the kept embargo child. It exposes `lifts_at`, `time_zone`, `enabled?`, `active?(at = Time.current)`, and `accepts_early_access_requests?`.

`recording.embargo_active?(at = Time.current)` is true while that embargo is enabled and `lifts_at` is still ahead. `RecordingStudioEmbargo.embargoed?(recording)` is the same check.

`accepts_early_access_requests` means people without access can ask for early access. It does not change who can see the recording.

`RecordingStudioEmbargo::Cache.key(recording, at: Time.current)` is the embargo id, `enabled`, and `lifts_at`. It has no actor, action, or visibility answer. `Cache.expires_in(recording, at:)` is the time left until `lifts_at` while the embargo is active.

`LiftTransitionJob` emits `embargo_lifted.recording_studio_embargo` when the stored `lifts_at` has arrived. It does not consult `embargo.manage` and it does not take an actor. A reschedule does not emit the old instant.

## Opt in

```ruby
class PressKit < ApplicationRecord
  recording_studio_recordable label: "Press kit", root: false
  include RecordingStudio::Capabilities::Embargo
end
```

Copying a recording must call `RecordingStudioEmbargo.attributes_for_duplicate`, which clears the window and turns early-access requests off.

The editor at `/recording_studio_embargo/recordings/:id/embargo/edit` is an enable switch, a release time, a time zone, and one early-access switch. Release date and time zone sit side by side and stack on a small screen. On a wide screen the editor stops at a medium width and stays full width below that. The explanation collapse sits below the form with space above it. Preview and hidden stay on the host. Default English copy lives in `config/locales/en.yml` under `recording_studio_embargo.editor`. The subtitle reads "Lock with embargo and set a release date". A collapse under the form, "What is an embargo", holds four paragraphs from `explanation_paragraphs`. The submit button reads "Update". The enable and early-access switches sit in the trailing slot of two Flatpack list rows, inside a Flatpack card with the card's default border and no extra card padding. A decorative lock icon leads the Embargo row, and a decorative open lock leads Early access. Each row name is a label that toggles its switch. Embargo's description is "Mark this as embargoed until the release time". Early access's description is "People without access can ask for early access". A host overrides `subtitle`, `explanation`, `enable`, and `accepts_early_access_requests` in its own locale file. The editor does not hardcode a recordable name.

## Host link

Include `RecordingStudioEmbargo::ApplicationHelper` (the engine does this for host views). Link to the editor with the recording the host already has. Embargo does not ask the host for an embargo id, and it does not render the host's menu.

```erb
<%= recording_studio_embargo_management_path(page_recording, return_to: request.fullpath) %>
```

`return_to:` is optional. After a full-page save, Embargo redirects there when the value is a same-origin path. Anything else is ignored, and the editor is shown again.

`embargoed?(page_recording)` is true only while a hold is on and the release time is still ahead. Use it for a lock or a label. `RecordingStudioEmbargo.embargoed?(recording)` is the same check outside a view.

## Manage gate

Showing the editor, saving an embargo, and clearing one all consult `embargo.manage`. Embargo does not register a check on that gate. With no checks registered, the gate allows, and existing hosts keep the current editor. Accessible's manage role stays a separate check. Both have to allow the change.

A host or another gem registers a check when it wants to refuse management. This plan check sends the visitor to a same-origin path. Embargo drops any other location and responds forbidden. A check that raises is a deny.

```ruby
RecordingStudio.register_gate("embargo.manage", "host.plan") do |actor:, recording:, **|
  if plan_allows_embargo?(actor)
    true
  else
    RecordingStudio::GateDecision.deny(redirect_to: "/plans")
  end
end
```

A consumer hides its own Embargo menu item, and refuses its own API, with the same gate.

```ruby
RecordingStudioEmbargo.manage_allowed?(recording: page_recording, actor: current_user)
```

`RecordingStudioEmbargo.manage_decision(recording:, actor:)` returns the `RecordingStudio::GateDecision` when the caller needs `redirect_to` or `reason`. Extra keywords are forwarded to each check.

`recording_studio_embargo_management_path` and `embargoed?` do not consult the gate. The host decides whether to show the link. `embargo_set!` and `embargo_cancel!` both consult the gate, and both still require the Accessible manage role. A denied gate refuses a clear, including a lapsed plan or a missing actor. The scheduled lift does not consult the gate.

## Host notice

`render_embargo_notice` is static copy. It is not an alert. It renders nothing when there is no embargo, the embargo is off, or the release time has passed. Anyone who can open the page sees it while the embargo is active, including people who cannot edit it.

```erb
<%= render_embargo_notice(page_recording) %>
<%= render_embargo_notice(page_recording, size: :sm, class: "mt-2", id: "page-embargo") %>
```

The card is `FlatPack::Card` with `background: :default`, `border: :strong` (a 2px outline), and `shadow: :none`. No card fill is plain white, so the notice adds `!bg-white`. The important modifier is required: the default fill is a later `background` shorthand, and a plain `bg-white` loses to it. Corners stay rounded. The space inside is one and a half times the compact card padding, at both sizes. The card is as wide as its words. Inside, a lock sits on the left of a bold title and a muted line. `size:` is `:md` by default, or `:sm` where space is tight. `class:` and `id:` pass through to the card.

The title reads "Embargoed until 12 Mar 2026, 9:00 AM AEDT". The time is `lifts_at` in the embargo's own time zone, with the zone abbreviation. The line under it reads "Not for publication until embargo lifts." Override `recording_studio_embargo.notice.title`, `recording_studio_embargo.notice.subtitle`, and `recording_studio_embargo.notice.time_format`. This needs Flatpack `0.1.315` or newer, so the card accepts `background:`, `border:`, and `shadow:`. `style:` is not a card argument.

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

Press Kits owns who can see a recording. This gem does not. The data a host reads is in [`docs/integration_plan.md`](docs/integration_plan.md).

## Install

```bash
bundle add recording_studio_embargo
bin/rails generate recording_studio_embargo:install
bin/rails generate recording_studio_embargo:migrations
bin/rails db:migrate
```

Migration details are in [`MIGRATION_NOTES.md`](MIGRATION_NOTES.md).

## Dummy app

The dummy app pins Recording Studio GitHub tag `v7.3.0`, Accessible GitHub tag `v0.45.1` (`>= 0.45.1`), Root Switchable GitHub tag `v0.16.0`, Metrics GitHub tag `v0.9.0`, Cache GitHub tag `v0.7.0`, Trashable GitHub tag `v1.0.0`, and FlatPack GitHub tag `v0.1.377`. The root Gemfile uses the same Recording Studio tag and FlatPack tag. The gemspec requires `recording_studio >= 7.0`, `< 8.0` and does not depend on Trashable. Accessible `0.45.1` needs Trashable `>= 0.17`, `< 2`. Root Switchable `0.16.0` needs Accessible `>= 0.44`, Cache `>= 0.5`, and Metrics `>= 0.9`. Trashable is `require: false` because Accessible loads only its query helpers. The dummy sets `config.authorize_write` so a present actor can write. Recording Studio 6.5 and newer refuses a write that has no authorizer or no actor. `config.layout` defaults to `nil`, which follows `RecordingStudio.configuration.layout` and then `"recording_studio/default_layout"`. The home page shows the embargo notice at the default size and at `:sm` for the seeded page. A More menu opens the editor in a host modal. "Open embargo page" opens the same editor as a page.

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Sign in as `admin@admin.com` / `Password`. The home page opens the embargo editor for the seeded page inside a Flatpack modal. `/recording_studio` redirects to `/`.

Authenticated pages use `recording_studio_layout`. With `config.layout` left at `nil`, that is Recording Studio's default layout. Devise keeps its own sign-in layout. Set `config.layout` to a layout name, `false`, or `->(controller:) { ... }` when a host wants a different shell.
