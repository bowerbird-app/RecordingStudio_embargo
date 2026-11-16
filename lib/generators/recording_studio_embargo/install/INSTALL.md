RecordingStudio Embargo install

1. Mount is added at the path you passed (default `/recording_studio_embargo`).
2. Review `config/initializers/recording_studio_embargo.rb`.
3. Opt a recordable in with `include RecordingStudio::Capabilities::Embargo`.
4. Install migrations: `bin/rails generate recording_studio_embargo:migrations`
5. Migrate: `bin/rails db:migrate`
6. Link with `recording_studio_embargo_management_path(recording, return_to:)` and `embargoed?(recording)`. The host chooses a page or its own modal. See the README.

See docs/integration_plan.md. Press Kits decides who can see the recording.
