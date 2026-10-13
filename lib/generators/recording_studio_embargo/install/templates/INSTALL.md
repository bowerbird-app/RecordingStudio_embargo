RecordingStudio Embargo install

1. Mount is added at the path you passed (default `/recording_studio_embargo`).
2. Review `config/initializers/recording_studio_embargo.rb` for auth, layout, and current actor integration.
3. Declare the recordable with `recording_studio_recordable`, then opt it in:
   `include RecordingStudio::Capabilities::Embargo.to(actions:, manage_role:)`.
4. Configure those actions on Accessible (`config.action_audiences`) before enabling an embargo.
5. Install migrations: `bin/rails generate recording_studio_embargo:migrations`
6. Migrate: `bin/rails db:migrate`
7. Rebuild Tailwind if the host renders the editor: `bin/rails tailwindcss:build`

Publishable, Downloadable, and Presskits are not modified by this generator.
See `docs/integration_plan.md` for the host calls those gems should make.
