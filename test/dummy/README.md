# Dummy App

This Rails app exists to validate Recording Studio Embargo in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Page opt-in for `RecordingStudio::Capabilities::Embargo.to`
- Accessible audiences for `pages.show` and `pages.download`
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dummy-only `/docs/*` pages for gem-specific onboarding

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - dummy app home page and a link to the embargo editor
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/recording_studio_embargo/recordings/:id/embargo/edit` - embargo editor
- `/samples/recordings/:id` - public presentation sample
- `/samples/recordings/:id/download` - download gate sample
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify embargo policy, the Flatpack editor, and host composition before changing Presskits or Downloadable. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before a host upgrade.
