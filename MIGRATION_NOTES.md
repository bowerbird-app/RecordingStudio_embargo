# Migration Notes

## Current requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.5.0`)
- Accessible, so the early-access switch and the editor's manage role resolve
- FlatPack dummy tag `v0.1.196` when the host renders the editor

Publishable, Downloadable, and Presskits are optional. Embargo does not read their tables.

## Schema

`recording_studio_embargo_embargoes` stores `enabled`, `lifts_at`, `time_zone`, and `early_access` (boolean). The row is a child recordable. A partial unique index, `index_rs_embargo_child_per_parent`, allows one untrashed `RecordingStudioEmbargo::Embargo` recording per parent. Revisions reuse that recording. There is no production data to backfill. Preview and hidden are not stored here.

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
