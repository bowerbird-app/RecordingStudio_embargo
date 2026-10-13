RecordingStudio Embargo install

1. Mount is added at the path you passed (default `/recording_studio_embargo`).
2. Review `config/initializers/recording_studio_embargo.rb`.
3. Opt a recordable in with `include RecordingStudio::Capabilities::Embargo.to(actions:, manage_role:)`.
4. Configure those actions on Accessible before enabling an embargo.
5. Install migrations: `bin/rails generate recording_studio_embargo:migrations`
6. Migrate: `bin/rails db:migrate`

See docs/integration_plan.md before wiring Presskits or Downloadable.
