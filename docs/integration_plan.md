# Embargo data

This gem stores one embargo on a recording. It does not decide who can see the recording, which presentation to use, or which actions are allowed. Press Kits owns visibility.

Embargo never writes publish times, visibility audiences, or download files.

## What a host reads

```ruby
recording.embargo_active?(at = Time.current)
embargo = recording.current_embargo
embargo.lifts_at
embargo.time_zone
embargo.enabled?
embargo.active?(at = Time.current)
embargo.accepts_early_access_requests?
```

`active?` is true when the embargo is enabled and `lifts_at` is still ahead. At `lifts_at` it is false. The row stays. The gem does not publish when the time arrives.

`accepts_early_access_requests` means people without access can ask for early access. It does not change who can see the recording.

`RecordingStudioEmbargo.embargoed?(recording)` is the same check as `embargo_active?`.

`RecordingStudioEmbargo.attributes_for_duplicate` returns `enabled: false`, `lifts_at: nil`, and `accepts_early_access_requests: false`. A copied recording starts from that hash. `revise` on the same child keeps history.

## Opt in

```ruby
class PressKit < ApplicationRecord
  recording_studio_recordable label: "Press kit", root: false
  include RecordingStudio::Capabilities::Embargo
end
```

There is no action list. `RecordingStudio::Capabilities::Embargo.to` is gone.

## Writes

`recording.embargo_set!(attrs, actor:)` and `recording.embargo_cancel!(actor:)` both consult `RecordingStudioEmbargo::MANAGE_GATE` (`"embargo.manage"`) and the Accessible manage role. A host check can refuse either call, including a lapsed plan or a missing actor. Embargo registers no check. With none registered, the gate allows.

The scheduled lift does not consult the gate and does not take an actor. `LiftTransitionJob` emits `embargo_lifted.recording_studio_embargo` when the stored `lifts_at` has arrived. A reschedule does not emit the old instant. The lift does not clear the row through `embargo_cancel!`. If `lifts_at` arrives while the recording is trashed, the job records nothing because `current_embargo` follows `Recording.kept`. Restoring the recording emits that lift once when it is already due, or schedules the job when the release is still ahead. A cancelled embargo does not lift.

## Cache

```ruby
RecordingStudioEmbargo::Cache.key(recording, at: Time.current)
RecordingStudioEmbargo::Cache.expires_in(recording, at: Time.current)
```

The key is the embargo id, `enabled`, and `lifts_at`. It does not include an actor, an action, or a visibility answer. `expires_in` is the time left until `lifts_at` while the embargo is active, and nil otherwise. The same helpers are `RecordingStudioEmbargo.cache_key` and `cache_expires_in`.

## Editor

The editor is an enable switch, a release time, a time zone, and one early-access switch. Hosts link to it with `recording_studio_embargo_management_path(recording, return_to:)`. The gem does not render a modal. A full-page save redirects to a same-origin `return_to`, or back to the editor. A frame save refreshes the page.

The early-access switch is "People without access can ask for early access." The enable description is "Mark this as embargoed until the release time."

```ruby
recording.embargo_set!(
  {
    enabled: params[:enabled],
    lifts_at: params[:lifts_at],
    time_zone: params[:time_zone],
    accepts_early_access_requests: params[:accepts_early_access_requests]
  },
  actor: current_actor
)
```
