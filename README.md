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

The editor at `/recording_studio_embargo/recordings/:id/embargo/edit` is an enable switch, a release time, a time zone, and one early-access switch. Preview and hidden stay on the host. Default English copy lives in `config/locales/en.yml` under `recording_studio_embargo.editor` and is written for a press kit. A host overrides `subtitle`, `enable_help`, and `early_access_help` in its own locale file. The editor does not hardcode press kit actions.

## Host button

Include `RecordingStudioEmbargo::ApplicationHelper` in the host helper, then render one button:

```erb
<%= render_embargo_button(page_recording) %>
```

The button is shown only to someone allowed to edit the embargo. With no embargo, or when it is disabled or already released, the button is secondary and reads "+ Embargo". While an embargo is active it uses the warning style, a lock icon, and the text "Embargoed". Both open the editor. There is no status badge and no one-click toggle. Hosts override `recording_studio_embargo.button.add` and `recording_studio_embargo.button.embargoed`.

## Host notice

`render_embargo_notice` is static copy. It is not an alert. It renders nothing when there is no embargo, the embargo is off, or the release time has passed. Anyone who can open the page sees it while the embargo is active, including people who cannot edit it.

```erb
<%= render_embargo_notice(page_recording) %>
<%= render_embargo_notice(page_recording, size: :sm, class: "mt-2", id: "page-embargo") %>
```

The card is `FlatPack::Card` with `style: :default`, `border: :strong` (a 2px outline), and `shadow: :none`. No card style is plain white, so the notice adds `!bg-white`. The important modifier is required: the default fill is a later `background` shorthand, and a plain `bg-white` loses to it. Corners stay rounded. Padding is compact. The card is as wide as its words. Inside, a lock sits on the left of a bold title and a muted line. `size:` is `:md` by default, or `:sm` where space is tight. `class:` and `id:` pass through to the card.

The title reads "Embargoed until 12 Mar 2026, 9:00 AM AEDT". The time is `lifts_at` in the embargo's own time zone, with the zone abbreviation. The line under it reads "Not for publication until embargo lifts." Override `recording_studio_embargo.notice.title`, `recording_studio_embargo.notice.subtitle`, and `recording_studio_embargo.notice.time_format`. This needs Flatpack `v0.1.237` or newer, so the card accepts `border:` and `shadow:`.

## Editor in a frame

A normal visit still renders the full editor page. When the request includes a `Turbo-Frame` header, the response is only the editor, with no page layout, so it can sit inside whatever container the host provides. This gem does not render a modal.

Pass `turbo_frame:` and the button loads that frame instead of navigating:

```erb
<%= render_embargo_button(page_recording, turbo_frame: "embargo_editor") %>
```

Leave `turbo_frame` out and the button keeps the current full-page link. The host owns the frame. A dialog, when you want one, is a Flatpack modal around that frame:

```erb
<%= render FlatPack::Modal::Component.new(id: "embargo-modal", size: :xl) do |modal| %>
  <% modal.body do %>
    <%= turbo_frame_tag "embargo_editor" %>
  <% end %>
<% end %>

<div data-modal-id="embargo-modal">
  <%= render_embargo_button(page_recording, turbo_frame: "embargo_editor") %>
</div>
```

Saving from inside the frame stays there. The editor shows "Embargo saved", and the button on the page updates to "Embargoed" or "+ Embargo". A validation error is shown in the same frame. A visit with no frame still redirects back to the full editor.

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

The dummy app pins Recording Studio dummy GitHub tag `v4.5.0`, Accessible dummy GitHub tag `v0.15.0`, Root Switchable dummy GitHub tag `v0.8.0`, and FlatPack dummy GitHub tag `v0.1.240`. The home page shows the embargo notice at the default size and at `:sm` for the seeded page.

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Sign in as `admin@admin.com` / `Password`. The home page opens the embargo editor for the seeded page inside a Flatpack modal. `/recording_studio` redirects to `/`.

Authenticated pages use Recording Studio's default layout. Devise keeps its own sign-in layout.
