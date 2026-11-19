# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.12.0] - 2026-11-19

### Changed

- Dummy and root Gemfiles pin Recording Studio `v7.8.0` (`~> 7.8`) and FlatPack `v0.2.0` (`~> 0.2`). The dummy pins Accessible `v0.55.0` (`>= 0.45.1`), Trashable `v1.2.3` (`require: false`), Root Switchable `v0.16.1`, Cache `v0.7.1`, and Metrics `v0.9.2`.

### Upgrade

Hosts MUST run the Recording Studio 7.4, 7.5, and 7.7 migrations if they have not.

flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration.

## [0.11.1] - 2026-11-18

### Changed

- Dummy and root Gemfiles pin Recording Studio `v7.7.1` and FlatPack `v0.1.378`. The dummy pins Accessible `v0.54.0` (`>= 0.45.1`), Trashable `v1.2.0` (`require: false`), Root Switchable `v0.16.0`, Cache `v0.7.0`, and Metrics `v0.9.1`.

## [0.11.0] - 2026-11-17

### Removed

- `RecordingStudioEmbargo.copy_onto!` and `attributes_for_duplicate` are gone. Embargo does not decide what a copied recording keeps. That belongs to the host, Press Kits, or Duplicatable.

### Added

- `RecordingStudioEmbargo.can_manage?(recording:, actor:)` is true when the actor passes the Accessible manage role and `embargo.manage`.

### Upgrade

`copy_onto!` and `attributes_for_duplicate` are gone. There is no copy helper to call instead. Check `RecordingStudioEmbargo.can_manage?(recording:, actor:)` before changing an embargo. To put a window on a copy, call `embargo_set!` with the source embargo's `lifts_at`, `time_zone`, and `accepts_early_access_requests`. `embargo_set!` and `embargo_cancel!` still require the manage role and `embargo.manage`. `manage_allowed?` is still only the gate.

## [0.10.2] - 2026-11-17

### Changed

- Copying a recording clears the embargo on the copy only when the actor passes both the Accessible manage role and `embargo.manage` for the source recording. An active window is kept (`enabled`, `lifts_at`, `time_zone`, `accepts_early_access_requests`) and the lift job is scheduled for the copy. A window that has already lifted is not copied. An embargo already on the destination is left unchanged unless that actor passes the manage role and `embargo.manage` for both the source and the destination. A missing actor never writes. Copying an active embargo without a person raises `RecordingStudioEmbargo::Unauthorized`. With no embargo, or after the window has lifted, the call does nothing.
- The `Cache` contract is documented as it behaves. `Cache.key` is the embargo id, `enabled`, and `lifts_at`. It does not include the recording id. `at:` does not change the key, because `stamp` ignores that argument. Callers namespace the key with their own recording or resource identity and use `Cache.expires_in` for the TTL.

### Upgrade

Call `RecordingStudioEmbargo.copy_onto!(source_recording:, copy_recording:, actor:)` when a recording is duplicated. Pass the person who is copying. A missing actor raises `RecordingStudioEmbargo::Unauthorized` when the source embargo is still active, and does nothing when there is no embargo or the window has already lifted. An embargo already on the destination is left unchanged unless the actor passes the manage role and `embargo.manage` for both the source and the destination. `attributes_for_duplicate(embargo, recording:, actor:)` returns the cleared hash only when that actor passes the Accessible manage role and `embargo.manage` for `recording`, or when the window is no longer active.

Do not write a kept window with `embargo_set!`. That call still requires the manage gate, so an actor who must keep the embargo cannot use it.

`Cache.key` and `Cache.expires_in` are unchanged.

## [0.10.1] - 2026-11-17

### Fixed

- Restoring a recording records an embargo lift that came due while the recording was trashed. `LiftTransitionJob` still finds the parent, but `current_embargo` uses `Recording.kept`, so a cascade-trashed embargo child is skipped and the job ends with no `embargo_lifted` event. After restore, a due enabled embargo emits that lift once. A future `lifts_at` schedules `LiftTransitionJob` again.

### Upgrade

No migration and no new dependency. `recording_studio_embargo` still does not depend on Trashable. The catch-up listens for a `"restored"` event on Recording Studio's `after_record` hook, which Trashable writes through `record!`. A cancelled embargo does not lift. A rescheduled embargo does not emit the old instant. The lift idempotency key is unchanged (`embargo-lifted-` plus `lifts_at`).

## [0.10.0] - 2026-11-16

### Changed

- Dummy and root Gemfiles pin Recording Studio `v7.3.0` and FlatPack `v0.1.377`. The dummy pins Accessible `v0.45.1` (`>= 0.45.1`), Trashable `v1.0.0` (`require: false`), Root Switchable `v0.16.0`, Cache `v0.7.0`, and Metrics `v0.9.0`.
- Dummy and root lockfiles move `puma` from `8.0.2` to `8.1.1` so Bundler Audit clears the Puma advisories fixed in `>= 8.0.3`.
- Embargo stores the window only. It does not decide who can see a recording.
- `RecordingStudioEmbargo::Restriction`, `restriction_for`, `action_permitted?`, `presskit_presentation`, `configuration.actions_for`, and `RecordingStudio::Capabilities::Embargo.to` are gone.
- Opt in with `include RecordingStudio::Capabilities::Embargo`.
- The column and attribute `early_access` is `accepts_early_access_requests`.
- `embargo_set!` and `embargo_cancel!` both consult `embargo.manage`.
- `Cache.key(recording, at:)` is the embargo id, `enabled`, and `lifts_at`.
- The scheduled lift does not consult the gate and does not take an actor. `embargo_lifted.recording_studio_embargo` is unchanged.

### Upgrade

Include the capability directly:

```ruby
include RecordingStudio::Capabilities::Embargo
```

Drop action lists. Drop `restriction_for`, `action_permitted?`, and `presskit_presentation`. Press Kits decides visibility.

The create migration stores `accepts_early_access_requests`. A database that already has `early_access` renames it:

```ruby
rename_column :recording_studio_embargo_embargoes, :early_access, :accepts_early_access_requests
```

There is no compatibility alias. Locale keys `editor.early_access` and `editor.early_access_description` are `editor.accepts_early_access_requests` and `editor.accepts_early_access_requests_description`. Lifecycle payloads use `accepts_early_access_requests`.

`embargo_cancel!` refuses when `embargo.manage` denies, including a lapsed plan or a missing actor. The scheduled lift does not consult that gate.

`RecordingStudioEmbargo.cache_key` and `RecordingStudioEmbargo::Cache.key` take `(recording, at: Time.current)`.

## [0.9.0] - 2026-11-15

### Changed

- Require `recording_studio` `>= 7.0`, `< 8.0`. Dummy and root Gemfiles pin GitHub tag `v7.0.0`. FlatPack stays `v0.1.366`. Metrics stays `v0.8.0`. Cache stays `v0.6.3`.
- Dummy pins move to Accessible `v0.43.1` (`>= 0.43.1`), Trashable `v0.16.1` (`require: false`), and Root Switchable `v0.15.1`. Those earlier tags stop before Recording Studio 7.
- Seeds and tests create roots with `RecordingStudio.create_root_recording!`. The dummy root-switch scope still looks roots up with `root_recording_for`.
- The dummy lockfile moves `msgpack` from `1.8.5` to `1.8.7` (CVE-2026-126366).

### Upgrade

Require `recording_studio` `>= 7.0`, `< 8.0`.

`RecordingStudio.root_recording_for` only finds a root. It returns `nil` when that recordable has none, and it does not write. Create a root with `RecordingStudio.create_root_recording!(recordable, actor:)`. A later call returns the existing root and does not append another event. Pass an actor, or set `config.actor`. No migration in this gem.

## [0.8.0] - 2026-11-14

### Changed

- Embargo child lookup, the dummy home page, and seeds use `RecordingStudio::Recording.kept`. Embargo no longer checks whether a `trashed_at` column exists.
- The partial unique index `index_rs_embargo_child_per_parent` is gone. Saving an embargo locks the parent and uses `Recording.kept` to revise the kept child or record a new one. A trashed embargo does not block a new one once a filter excludes it from `kept`.
- Require `recording_studio` `>= 6.14.0`. Dummy and root Gemfiles pin GitHub tag `v6.14.0`. FlatPack stays `v0.1.366`. The dummy pins Accessible `>= 0.42.0` at tag `v0.42.0`, Root Switchable `v0.15.0`, Metrics `v0.8.0`, and Cache `v0.6.3`. Accessible 0.42 requires Trashable `>= 0.16.0`, so the dummy pin is tag `v0.16.0` (`require: false`).
- The dummy copies Recording Studio migration `20261114090000_add_root_recording_id_to_recording_studio_events`. Recording Studio 6.9 requires `recording_studio_events.root_recording_id`.
- The dummy Gemfile no longer loads `widen_recording_studio_requirement`. Those sibling tags accept Recording Studio 6.
- The dummy root-switch scope lists workspace roots the actor can view. Root Switchable 0.15 requires Accessible `:view` on the current root before the switch page renders.

### Upgrade

Require `recording_studio` `>= 6.14.0`.

Kept rows come from filters registered with core. This gem does not depend on `recording_studio_trashable` and does not register a filter. With none registered, `Recording.kept` matches every recording, so a save revises the existing embargo child. Trashable `0.16.0` registers the `trashed_at` filter; after that, a trashed embargo is not kept and a save can record a new one. The dummy pins that tag.

Run `bin/rails generate recording_studio_embargo:migrations` and migrate. That drops `index_rs_embargo_child_per_parent` if a previous install created it. The index is not rebuilt.

## [0.7.0] - 2026-11-13

### Added

- `embargo.manage` is consulted before the editor is shown and before `Services::Embargoes::Upsert`, including `embargo_set!`. `embargo_cancel!` does not consult the gate. It still requires the Accessible manage role. `RecordingStudioEmbargo.manage_allowed?(recording:, actor:)` reports the boolean. `manage_decision(recording:, actor:)` returns the `RecordingStudio::GateDecision`. Embargo registers no check, so the gate allows until a host or another gem registers one.

### Upgrade

Require `recording_studio` `>= 6.7.0`.

Register a check on `embargo.manage` when management should be refused. This plan check sends the visitor to a same-origin path. Any other `redirect_to` is ignored, and the editor responds forbidden. A check that raises denies the change. The Accessible manage role is unchanged and still has to allow the editor.

```ruby
RecordingStudio.register_gate("embargo.manage", "host.plan") do |actor:, recording:, **|
  if plan_allows_embargo?(actor)
    true
  else
    RecordingStudio::GateDecision.deny(redirect_to: "/plans")
  end
end
```

Consumers call `RecordingStudioEmbargo.manage_allowed?(recording:, actor:)` to hide their own Embargo menu item or refuse their own API. `recording_studio_embargo_management_path` and `embargoed?` stay available. An active embargo still restricts actions while this gate denies. `embargo_cancel!` is not gated, so a denied gate can still clear an existing hold. The gate is not used by enforcement or by `LiftTransitionJob`.

## [0.6.5] - 2026-11-13

### Changed

- Dummy and root Gemfiles pin Recording Studio tag `v6.7.0`. The gemspec still requires `recording_studio >= 6.1.0`. The lockfiles move `minitest` to `6.1.0` and `irb` to `1.19.0`.
- The dummy initializer sets `config.authorize_write` to allow a write when an actor is present.
- A scheduled lift passes the actor stored on the embargo recording into `log_event!`.

### Upgrade

No embargo method change. Recording Studio 6.5 and newer raises `AuthorizationError` when `config.authorize_write` is missing, and `ActorRequired` when the actor is missing. Set the authorizer in the host app, and pass an actor on each write. The dummy allows a write when the actor is present. Embargo already passes the editor actor through `Upsert`, `Cancel`, and lifecycle history. The lift uses the actor stored on the embargo recording. Leave `allow_unauthorized_writes` unset. Recording Studio 6.7 requires Rails `>= 8.1.4.1`. This release does not register a gate.

## [0.6.4] - 2026-11-05

### Changed

- Dummy and root lockfiles use Rails `8.1.4.1`. Bundler also moved the Rails stack and a few forced deps (`json`, `uri`, `prettyprint`, `io-console`, `date`, `rack-test`, `net-imap`). `rack` stays `3.2.8`, `nokogiri` `1.19.7`, `loofah` `2.25.3`, `rails-html-sanitizer` `1.7.2`, dummy `net-ssh` `7.3.8`.

## [0.6.3] - 2026-11-03

### Changed

- Editor switch rows use FlatPack `List::Item` `title:` and `subtitle:` slots. The switch labels stay in `with_title`. The `FlatPack::Text` descriptions stay in `with_subtitle` with the same `id`s so `aria-describedby` still resolves.
- Requires `flat_pack >= 0.1.335`. Dummy and root Gemfiles pin GitHub tag `v0.1.335`.
- Dummy and root lockfiles use `loofah` `2.25.3`, `nokogiri` `1.19.7`, and `rails-html-sanitizer` `1.7.2`.

### Upgrade

Use FlatPack `≥ 0.1.335` if you render the embargo editor.

## [0.6.2] - 2026-11-02

### Changed

- The editor switch descriptions render with `FlatPack::Text` (`as: :p`, `size: :xs`, `style: :muted`). The same `id`s stay on those paragraphs so the switches keep `aria-describedby`.
- Dummy Sign out uses Button `href:` instead of `url:`.
- Dummy and root Gemfiles pin FlatPack GitHub tag `v0.1.331`. The engine editor now needs FlatPack `≥ 0.1.331` for `Text`. The gemspec still does not declare `flat_pack`, so hosts that render the editor must pin it themselves. FlatPack Grid now uses `--stack-gap-*` tokens instead of `gap-6`.

### Upgrade

Use FlatPack `≥ 0.1.331` if you render the embargo editor. There is no new gemspec dependency. Replace Button `url:` with `href:` on FlatPack `≥ 0.1.177`.

## [0.6.1] - 2026-11-02

### Changed

- Dummy README pin text matches the Gemfiles: Recording Studio `v6.1.0`, Accessible `v0.15.0`, Root Switchable `v0.8.0`, Metrics `v0.2.0`, and FlatPack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`).
- Dummy `coverage/` is ignored. Root and dummy lockfiles use `rack` `3.2.8`.

## [0.6.0] - 2026-10-26

### Changed

- Requires `recording_studio` `>= 6.1.0` and FlatPack `>= 0.1.315`. The dummy app pins Recording Studio tag `v6.1.0` and FlatPack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`0.1.319`).
- `RecordingStudioEmbargo.configuration.layout` defaults to `nil`. Assignments go through `RecordingStudio::Layout.accept`. `nil` follows `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. `false` skips the layout. A callable must be `->(controller:) { ... }` and return a String, `nil`, or `false`.
- Engine controllers call `recording_studio_layout { RecordingStudioEmbargo.configuration.layout }`.
- The editor page sets `content_for :title` and `content_for :subtitle`, and back uses `flat_pack_page_nav`. A Turbo Frame request still draws the heading inside the frame.
- The embargo notice passes `background: :default` to `FlatPack::Card`. `style:` is no longer a card argument.

### Removed

- `include RecordingStudio::UsesDefaultLayout`.
- `recording_studio_page_nav` and the inline page heading on a full-page editor visit.

### Upgrade

Require `recording_studio` `>= 6.1.0` and FlatPack `>= 0.1.315` (`view_component` `>= 4.14, < 5`). Drop `include RecordingStudio::UsesDefaultLayout` and any `layout "recording_studio/default_layout"` or `layout "recording_studio/action_layout"`. Call `recording_studio_layout` on the host controller. Leave `config.layout` at `nil` to keep the shared shell, or set a layout name, `false`, or `->(controller:) { ... }`. Replace `recording_studio_page_nav` with `content_for :title`, `content_for :subtitle`, and `flat_pack_page_nav`. Drop `style:` on `FlatPack::Card`. The notice now uses `background:`.

## [0.5.0] - 2026-10-22

### Changed

- The editor subtitle is "Lock with embargo and set a release date".
- Embargo and early access are two rows in a Flatpack list, inside a Flatpack card. The card uses its default border and no extra padding, so the rows keep their own inset. A decorative lock icon leads the Embargo row, and a decorative open lock leads Early access. Each row has a name and a short description. The name is a label for the switch in the trailing slot. The description is tied to that switch with `aria-describedby`. Embargo reads "Show preview only and mark as embargoed". Early access reads "Allow people to request early access". The old switch help text is gone. Release date and time zone stay under the list.
- The explanation of an embargo sits in a collapse titled "What is an embargo", under the form. It is four paragraphs from `explanation_paragraphs`.
- Release date and time zone sit side by side. They stack on a small screen. Form rows use the large grid gap, and the date and time zone pair uses that same gap.
- The editor column is at most `max-w-3xl` and stays full width on a narrow screen.
- The "What is an embargo" collapse has space above it.
- The submit button reads "Update".

### Removed

- The "When it lifts" fieldset, and the `recording_studio_embargo.editor.fieldset` locale key.

### Upgrade

Drop any override of `recording_studio_embargo.editor.fieldset`, `recording_studio_embargo.editor.explanation`, `enable_help`, and `early_access_help`. The explanation is now the array `explanation_paragraphs`. The subtitle no longer takes `%{recordable_name}`. `enable` now reads "Embargo". The row descriptions are `enable_description` and `early_access_description`. The save key is still `recording_studio_embargo.editor.save`. Its default is now "Update".

## [0.4.0] - 2026-10-21

### Added

- `recording_studio_embargo_management_path(recording, return_to: nil)` is the editor link. The host passes the recording it already has.
- `embargoed?(recording)` and `RecordingStudioEmbargo.embargoed?(recording)` are true while a hold is on and the release time is still ahead.
- A full-page save redirects to a same-origin `return_to`. Any other value is ignored, and the editor is shown again.
- A save inside a Turbo Frame responds with `turbo_stream.refresh` (`method="morph"`, `scroll="preserve"`). The host page renders again. Embargo does not replace host markup.
- `config.broadcast_page_refresh` (default `true`). When turbo-rails is loaded, create, update, cancel, and a scheduled lift broadcast a page refresh with `Turbo::StreamsChannel.broadcast_refresh_to(recording)`. The broadcast is skipped when the setting is off or turbo-rails is not loaded.
- Those same events touch the parent recording so a fragment cache keyed on it rebuilds.

### Removed

- `render_embargo_button`, `EmbargoButton`, and the wrapper id it used to replace after save. Hosts render their own Flatpack link or menu item.

### Upgrade

Drop `render_embargo_button` and any `turbo_frame:` passed to it. Render a host link with `recording_studio_embargo_management_path`. Use `embargoed?` for a lock or a label. `render_embargo_notice` stays. Set `config.broadcast_page_refresh = false` when a host should not receive the page refresh. Subscribe with `turbo_stream_from recording` to pick it up.

## [0.3.1] - 2026-10-15

### Changed

- The embargo notice has more room inside the card, at both sizes. Padding is one and a half times the compact card padding (`0.75rem` becomes `1.125rem`). Named body sizes are `1rem` and `1.25rem`, so the body uses that scale directly. The white fill, 2px border, and lack of shadow stay.

### Upgrade

No call-site change. `render_embargo_notice` renders the roomier card on its own.

## [0.3.0] - 2026-10-15

### Added

- `render_embargo_notice(recording, size: :md, **options)` shows a white Flatpack card while an embargo is active. It renders nothing when the embargo is off or the release time has passed. The card uses `style: :default`, `border: :strong`, `shadow: :none`, and `!bg-white`. No card style is plain white, and a plain `bg-white` loses to the card's later background shorthand.
- The title, the line under it, and the release-time format live in `config/locales/en.yml` under `recording_studio_embargo.notice`.

### Upgrade

Existing button and editor calls stay the same. Render `render_embargo_notice(recording)` where the notice should appear. `size:` is `:md` or `:sm`. `class:` and `id:` pass through to the card. The card uses Flatpack `style: :default`, `border: :strong`, and `shadow: :none`, which need Flatpack `v0.1.237` or newer. Override `recording_studio_embargo.notice.title`, `.subtitle`, and `.time_format` for different words or a different clock format.

## [0.2.0] - 2026-10-15

### Added

- A request with a `Turbo-Frame` header renders the editor without the page layout, so a host can place it in its own container.
- `render_embargo_button` accepts `turbo_frame:`. The button then loads that frame. Leave it out and the button still opens the full editor.
- Saving inside a frame stays in the frame, shows "Embargo saved", and refreshes the button to "Embargoed" or "+ Embargo". Validation errors re-render in the frame. A normal visit still redirects to the editor.

### Upgrade

No change for hosts that open the editor as a page. To drop it into a dialog, add your own Flatpack modal and Turbo frame, then pass `turbo_frame:` to the button. This gem does not render a modal.

## [0.1.0] - 2026-10-13

### Added

- `render_embargo_button` shows a Flatpack button that opens the editor. It reads "+ Embargo" until an embargo is active, then "Embargoed" with a lock. People who cannot edit see nothing.
- `RecordingStudio::Capabilities::Embargo.to` opts a recordable into one current embargo child.
- `RecordingStudioEmbargo.restriction_for` returns `:allow`, `:deny`, or `:not_applicable`. Early access is a boolean. On uses Accessible's `:granted` audience per listed action. Off denies every actor.
- `action_permitted?` and `presskit_presentation` compose that decision with a public baseline and with Publishable's `currently_published?` when the recording implements it.
- Enabling an embargo requires a future `lifts_at` and a known time zone. Expired rows stay as history. Cancel clears `enabled` and keeps the events.
- `LiftTransitionJob` emits one `embargo_lifted` notification for the stored instant. A reschedule does not emit the old instant. Authorization does not wait for the job.
- Flatpack editor for enable, release time, time zone, and one early-access switch. Listed actions come from the host capability. Preview and hidden stay on the host.
- Install generator, migrations generator, and `docs/integration_plan.md` for the Downloadable and Presskits follow-ups.

### Changed

- Default editor copy is plain press-kit language in `config/locales/en.yml`, so a host can override the subtitle and help text.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.12.0...HEAD
[0.12.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.11.1...v0.12.0
[0.11.1]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.11.0...v0.11.1
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.6.5...v0.7.0
[0.6.5]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.6.4...v0.6.5
[0.6.4]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.6.3...v0.6.4
[0.6.3]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/releases/tag/v0.1.0
