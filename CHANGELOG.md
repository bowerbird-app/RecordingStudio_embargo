# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-10-22

### Changed

- The editor subtitle is "Lock with embargo and set a release date".
- Embargo and early access are two rows in a Flatpack list, inside a Flatpack card. The card uses its default border and no extra padding, so the rows keep their own inset. Each switch sits in the row's trailing slot. The left label is "Embargo" or "Early access" and is a label for that switch. The old switch help text is gone. Release date and time zone stay under the list.
- The explanation of an embargo sits in a collapse titled "What is an embargo", under the form.
- Release date and time zone sit side by side. They stack on a small screen. Form rows use the large grid gap, and the date and time zone pair uses that same gap.
- The editor column is at most `max-w-3xl` and stays full width on a narrow screen.
- The "What is an embargo" collapse has space above it.
- The submit button reads "Update".

### Removed

- The "When it lifts" fieldset, and the `recording_studio_embargo.editor.fieldset` locale key.

### Upgrade

Drop any override of `recording_studio_embargo.editor.fieldset`, `enable_help`, and `early_access_help`. The subtitle no longer takes `%{recordable_name}`. `enable` now reads "Embargo". The save key is still `recording_studio_embargo.editor.save`. Its default is now "Update".

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/releases/tag/v0.1.0
