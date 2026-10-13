# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_embargo/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_embargo/releases/tag/v0.1.0
