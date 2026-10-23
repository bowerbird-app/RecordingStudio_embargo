# Integration plan

This gem is the embargo. Publishable, Downloadable, and Presskits stay unchanged in this pull request. Hosts can call the methods below today. The sibling gems should grow the hooks in the follow-up sections so every public entry point uses the same decision.

Embargo never writes `publish_at`, `unpublish_at`, `time_zone` on a publishable, visibility audiences, or download files.

## Shared contract

```ruby
decision = RecordingStudioEmbargo.restriction_for(recording:, action:, actor:)
# :allow, :deny, :not_applicable
```

- Active means `enabled` and `Time.current < lifts_at`. At `lifts_at` the decision is `:not_applicable` with no job.
- Only actions passed to `Embargo.to(actions:)` are restricted. A host that wants both view and download held must list both. `early_access` is a boolean on the embargo, not a per-action audience.
- Early access on evaluates Accessible's `:granted` audience for that action. A view grant does not satisfy an action whose granted roles are edit or admin. Early access off denies every actor.
- `:deny` restricts the action even when the baseline audience is `:public`. Do not implement this as `authorized_action? && early_access`. `authorized_action?` is true for every actor when the baseline is `:public`, so that expression lets the public audience through.
- `:allow` means the actor passes early access only. The host still checks publication, the baseline audience, and domain authorization.
- `:not_applicable` means embargo has nothing to say. Use the normal policy.
- Cache keys must include the actor and the decision, and a stored response must not outlive `lifts_at`. `RecordingStudioEmbargo.cache_key` and `cache_expires_in` do that. Prefer `Cache-Control: private, no-store` on an active embargo response, including an early-access `:full` body.
- Trashed recordings are `:deny` while the embargo is active.

`RecordingStudioEmbargo.action_permitted?` is the safe composition for a boolean gate:

1. Missing or trashed recording: false.
2. `purpose: :public` and the recording responds to `currently_published?` with false: false. Recordings without that method are treated as live.
3. Restriction `:deny`: false.
4. Otherwise `RecordingStudioAccessible.authorized_action?`.

`RecordingStudioEmbargo.presskit_presentation` is the safe composition for `:full`, `:preview`, `:hidden`, and `:unavailable`.

## Publishable

No code change.

`currently_published?` remains `status == published` and the publish window contains now. Embargo does not change status and does not publish when `lifts_at` arrives. A draft or a scheduled post stays withheld through `action_permitted?` / `presskit_presentation` even if the actor has early access. An editor with Accessible `:view` still receives `:full` from `presskit_presentation` when `purpose: :editor` and the recording is unpublished. That matches Presskits today.

If `lifts_at` and `publish_at` are the same instant, the embargo is already inactive (`lifts_at > now` is false) and Publishable is live (`publish_at <= now`). The public baseline applies at that instant.

## Downloadable

Follow-up in `RecordingStudio_downloadable`.

`PackagesController#show`, `#create`, and `#status` all call `authorize_download!` in `app/controllers/recording_studio_downloadable/application_controller.rb`. That calls `Authorization.authorize!`, which calls `Authorization.allowed?` in `lib/recording_studio_downloadable/authorization.rb`.

Change `allowed?` so a `:deny` returns false before `audience_allows?`:

```ruby
def allowed?(action:, actor:, recording:, capability_options: nil, controller: nil)
  return false unless downloadable_enabled?(recording: recording, capability_options: capability_options)
  return false if embargo_denies?(action: action, actor: actor, recording: recording)

  return false unless audience_allows?(
    action: action,
    actor: actor,
    recording: recording,
    capability_options: capability_options,
    controller: controller
  )

  domain_available?(actor: actor, recording: recording, action: action)
end

def embargo_denies?(action:, actor:, recording:)
  return false unless defined?(RecordingStudioEmbargo)

  RecordingStudioEmbargo.restriction_for(recording: recording, action: action, actor: actor) == :deny
end
```

`action` is already `recording.downloadable_action`. For a press kit that is `:"presskits.kit_download"`. The embargo capability on that recordable must list the same action. A `:view` grant does not pass this action unless the host's Accessible `granted_roles` for it say so. Presskits' `KitDownload::ACTION` defaults are `granted_roles: %i[download edit admin]` and `granted_override: true`.

This check runs on every show, create, and status request, so an existing ZIP is refused to an actor who fails early access. After `lifts_at`, restriction is `:not_applicable` and the baseline audience (often `:public`) allows the existing ZIP. Do not rebuild the archive because the clock passed.

Issued Active Storage signed URLs stay valid until their own expiry. Do not add an endpoint that skips `authorize_download!`. Keep `urls_expire_in` short.

`downloadable_available_for?` can also consult `restriction_for` as a second host hook. The authorization change above is the one that covers the three package routes. Do not let a domain hook allow a request that `allowed?` denied.

## Presskits

Follow-up in `RecordingStudio_presskits`. Do not build a combined Locked/Unlocked screen.

### Visibility

`RecordingStudioPresskits::Visibility.presentation_for` in `lib/recording_studio_presskits/visibility.rb` is the only policy public controllers, cards, meta tags, and listings should use. Today, after `published?`, it returns `:full` when `authorized_full?` (`authorized_action?` for `:"presskits.kit_view_full"`). That is the public-baseline bypass.

Keep the unpublished branch as it is. After the recording is published, deny through embargo before the baseline:

```ruby
def presentation_for(actor:, kit:, purpose: :public)
  recording = recording_for(kit)
  return :unavailable if recording.blank?

  unless published?(recording)
    return :full if purpose.to_sym == :editor && editor?(actor, recording)

    return :unavailable
  end

  if embargo_denies?(actor, recording)
    return policy_for(recording).fetch(:fallback)
  end

  return :full if authorized_full?(actor, recording)

  policy_for(recording).fetch(:fallback)
end

def embargo_denies?(actor, recording)
  return false unless defined?(RecordingStudioEmbargo)

  RecordingStudioEmbargo.restriction_for(
    recording: recording,
    action: ACTION,
    actor: actor
  ) == :deny
end
```

`ACTION` stays `:"presskits.kit_view_full"`. Do not change `effective_audience` storage. Early access is the boolean on the embargo row. Preview and hidden stay on the kit's existing visibility fallback. The embargo editor does not store a presentation.

`Visibility.discoverable?` already calls `presentation_for`. `KitQuery.discoverable_for` in `lib/recording_studio_presskits/kit_query.rb` calls `discoverable?`, so the listing becomes embargo-aware without a second policy. Hidden and unavailable stay out of that list. Preview stays in it.

`PublicPressKitsController#show` already renders sections only for `:full`. Once `presentation_for` returns `:preview` or `:hidden`, protected sections and assets stay off that page. Audit meta tags that call `presentation_for` or `authorized_full?` directly and route them through `presentation_for`.

`apply_public_response!` currently sets `private, no-store` unless the presentation is `:full`. An early-access `:full` response must also be private and must not outlive `lifts_at`. Set `private, no-store` whenever `recording.respond_to?(:embargo_active?) && recording.embargo_active?`.

`fragment_cache_key` should append `RecordingStudioEmbargo.cache_key(recording, actor, ACTION)` while an embargo exists, so a public fragment is not reused for an early-access actor or after the window changes.

### Downloads

Press kit ZIP routes are Downloadable's package routes. The Downloadable change above is what blocks generate, fetch, and status. Presskits still registers `KitDownload::ACTION`. The kit's embargo capability must list `:"presskits.kit_download"` or download is not restricted. Early access on uses that action's granted roles.

### Editor

Add a kit screen beside Visibility and Downloads. It is a follow-up, not part of the embargo gem. The screen posts to the host, and the host calls:

```ruby
recording.embargo_set!(
  {
    enabled: params[:enabled],
    lifts_at: params[:lifts_at],
    time_zone: params[:time_zone],
    early_access: params[:early_access]
  },
  actor: current_actor
)
```

Include the capability on the press kit recordable with both actions. Keep preview and hidden on the kit visibility screen.

```ruby
include RecordingStudio::Capabilities::Embargo.to(
  actions: [ :"presskits.kit_view_full", :"presskits.kit_download" ]
)
```

The generic editor in this gem is the reference implementation: enable, release time, a time zone, and one early-access switch. Hosts link to it with `recording_studio_embargo_management_path(recording, return_to:)`. `embargoed?(recording)` is the active hold. Put that link in the host's own Flatpack menu. Pass `data-turbo-frame` when the link should load the editor into a host-owned frame, for example the body of a Flatpack modal the host renders. The gem does not render a modal, and it does not replace the host's markup after save. A frame save refreshes the page. A full-page save redirects to a same-origin `return_to`, or back to the editor. Default copy lives in the gem locale. The subtitle is "Lock with embargo and set a release date". Each switch sits in the trailing slot of a list row. The left label is a `label` for that switch, from `enable` and `early_access`. The list is inside a Flatpack card with the card's default border and `padding: :none`, so the rows keep their own inset. Do not hardcode press kit actions inside the gem, and do not merge this screen with the visibility or download editors. Optional `turbo_stream_from recording` picks up the page refresh Embargo broadcasts when `broadcast_page_refresh` is on.

## Copying recordings

`revise` keeps history on the same child recording. A new parent recording, the product copy, must start from `RecordingStudioEmbargo.attributes_for_duplicate`: `enabled: false`, `lifts_at: nil`, `early_access: false`. Do not copy Accessible grants as part of embargo. Grants belong to Accessible and are not duplicated by this gem.
