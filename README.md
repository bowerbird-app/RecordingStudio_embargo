# RecordingStudio Embargo

Recording Studio capability that holds named actions until a release time. Early access uses Accessible audiences. Embargo does not publish, grant access, or build downloads.

## What it decides

`RecordingStudioEmbargo.restriction_for(recording:, action:, actor:)` returns:

- `:not_applicable` when no enabled embargo lists that action, or `Time.current` is at or after `lifts_at`
- `:allow` when the actor satisfies that action's early-access audience
- `:deny` otherwise, including when the baseline audience is `:public`

`:allow` does not authorize the action. Hosts still enforce publication, the baseline audience, and domain rules. `:deny` does restrict the action. A public baseline is not combined with early access, because a public audience is true for every actor and would skip the embargo.

```ruby
RecordingStudioEmbargo.action_permitted?(recording:, action:, actor:)
RecordingStudioEmbargo.presskit_presentation(recording:, actor:, view_action:)
```

`action_permitted?` is false when Publishable says the recording is not currently published, when the embargo denies the actor, or when the baseline audience denies the actor. `presskit_presentation` keeps the Presskits order: unpublished stays `:unavailable` (editors with view access still get `:full`), an embargo denial uses the configured `preview` or `hidden` fallback, and everyone else uses the normal visibility result.

Expiry is read at authorization time. `LiftTransitionJob` only emits `:embargo_lifted`, and it no-ops unless the stored `lifts_at` still matches the scheduled instant.

## Opt in

```ruby
class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false
  include RecordingStudio::Capabilities::Embargo.to(
    actions: [ :"pages.show", :"pages.download" ],
    fallbacks: %w[preview hidden],
    manage_role: :edit
  )
end
```

Configure those same actions on Accessible before enabling an embargo. One action's early-access audience does not cover another action. Copying a recording must call `RecordingStudioEmbargo.attributes_for_duplicate`, which clears the window and the early-access list.

The editor at `/recording_studio_embargo/recordings/:id/embargo/edit` renders the actions and fallbacks supplied by the capability. It does not know about press kits.

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

The dummy app pins Recording Studio dummy GitHub tag `v4.5.0`, Accessible dummy GitHub tag `v0.15.0`, Root Switchable dummy GitHub tag `v0.8.0`, and FlatPack dummy GitHub tag `v0.1.196`.

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Sign in as `admin@admin.com` / `Password`. The home page opens the embargo editor for the seeded page. `/recording_studio` redirects to `/`.

Authenticated pages use Recording Studio's default layout. Devise keeps its own sign-in layout.
