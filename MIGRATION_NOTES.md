# Migration Notes

## Current requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 6.1.0` (dummy GitHub tag `v6.3.0`)
- Accessible, so the early-access switch and the editor's manage role resolve
- Recording Studio API is optional. This gem registers `set_embargo`, `cancel_embargo`, and `show_embargo` when that engine is present and exposes `each_api` plus `register_capability_action(api:)`. List those names on the recordable type API. Authorization uses the HTML manage role (`:edit` unless `Embargo.to` sets `manage_role:`).
- FlatPack `>= 0.1.335` when the host renders the editor (`List::Item` `title:` / `subtitle:` slots and `FlatPack::Text`). The dummy pins GitHub tag `v0.1.341` for Recording Studio API. `render_embargo_notice` still needs FlatPack `>= 0.1.315` for Card `background:`, `border:`, and `shadow:`. The gemspec requires `flat_pack >= 0.1.335`.
- `view_component` `>= 4.14, < 5`. The dummy locks `4.19.0`.

`RecordingStudio::UsesDefaultLayout` is gone. Engine controllers call `recording_studio_layout { RecordingStudioEmbargo.configuration.layout }`. `config.layout` defaults to `nil`. `nil` follows `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. `false` renders with no layout. A callable is invoked as `call(controller:)` and must return a String, `nil`, or `false`.

Page headings are `content_for :title` and `content_for :subtitle`. Back and close use `flat_pack_page_nav`. A Turbo Frame request still renders the editor heading inside the frame, because the frame has no page layout.

Publishable, Downloadable, and Presskits are optional. Embargo does not read their tables.

## Schema

`recording_studio_embargo_embargoes` stores `enabled`, `lifts_at`, `time_zone`, and `early_access` (boolean). The row is a child recordable. A partial unique index, `index_rs_embargo_child_per_parent`, allows one untrashed `RecordingStudioEmbargo::Embargo` recording per parent. Revisions reuse that recording. There is no production data to backfill. Preview and hidden are not stored here.

## Host linking

Hosts link to the editor with `recording_studio_embargo_management_path(recording, return_to:)`. `embargoed?(recording)` reports an active hold. The editor is the same view as a page or inside a host Turbo Frame. Embargo does not render a modal and does not replace host markup after save. A full-page save redirects to a same-origin `return_to`, or back to the editor. A frame save responds with a morphing page refresh.

`config.broadcast_page_refresh` defaults to true. When turbo-rails is loaded, create, update, cancel, and a scheduled lift broadcast `Turbo::StreamsChannel.broadcast_refresh_to(recording)`. Set it to false to skip that broadcast. Those same events touch the parent recording so fragment caches keyed on it rebuild.

`render_embargo_button`, `EmbargoButton`, and its wrapper id are gone. `render_embargo_notice` is unchanged.

## Install

From the host app:

```bash
bin/rails generate recording_studio_embargo:install
bin/rails generate recording_studio_embargo:migrations
bin/rails db:migrate
```

The install generator mounts the engine, copies `config/initializers/recording_studio_embargo.rb`, and adds the engine views to the Tailwind source when `app/assets/tailwind/application.css` imports Tailwind. Opt a recordable in with `RecordingStudio::Capabilities::Embargo.to` and configure the same actions on Accessible.

Copying a parent recording must not copy an active embargo. Apply `RecordingStudioEmbargo.attributes_for_duplicate` on the new recording.

## Verification

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory:

```bash
cd test/dummy
bin/dev
```
