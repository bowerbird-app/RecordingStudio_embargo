# frozen_string_literal: true

require "test_helper"

class RecordingStudioEmbargoTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.6.0", ::RecordingStudioEmbargo::VERSION
  end

  def test_editor_frame_support_does_not_know_about_modals
    root = File.expand_path("..", __dir__)
    sources = %w[
      app/controllers/recording_studio_embargo/embargoes_controller.rb
      app/helpers/recording_studio_embargo/application_helper.rb
      app/views/recording_studio_embargo/embargoes/edit.html.erb
      app/views/recording_studio_embargo/embargoes/_editor.html.erb
      lib/recording_studio_embargo/return_to.rb
      lib/recording_studio_embargo/host_refresh.rb
    ].map { |path| File.read(File.join(root, path)) }

    sources.each do |source|
      refute_includes source, "modal_id"
      refute_includes source, "FlatPack::Modal"
      refute_includes source, "flat_pack_modal_screen"
      refute_includes source, "EmbargoButton"
      refute_includes source, "wrapper_id"
      refute_includes source, "recording_studio_page_nav"
      refute_includes source, "UsesDefaultLayout"
    end

    edit = File.read(File.join(root, "app/views/recording_studio_embargo/embargoes/edit.html.erb"))
    assert_includes edit, "content_for :title"
    assert_includes edit, "content_for :subtitle"
    assert_includes edit, "flat_pack_page_nav"

    helper = File.read(File.join(root, "app/helpers/recording_studio_embargo/application_helper.rb"))
    assert_includes helper, "def recording_studio_embargo_management_path(recording, return_to: nil)"
    assert_includes helper, "def embargoed?(recording)"
    refute_includes helper, "render_embargo_button"
    refute File.exist?(File.join(root, "app/views/recording_studio_embargo/embargoes/update.turbo_stream.erb"))
  end

  def test_controllers_do_not_hardcode_a_recording_studio_layout
    root = File.expand_path("..", __dir__)
    application = File.read(File.join(root, "app/controllers/recording_studio_embargo/application_controller.rb"))
    embargoes = File.read(File.join(root, "app/controllers/recording_studio_embargo/embargoes_controller.rb"))

    assert_includes application, "recording_studio_layout { RecordingStudioEmbargo.configuration.layout }"
    refute_includes embargoes, "layout \"recording_studio/"
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(root)
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioEmbargo::Engine
  end

  def test_gemspec_requires_recording_studio_6_1
    gemspec = File.read(File.expand_path("../recording_studio_embargo.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", ">= 6.1.0"'
    refute_includes gemspec, 'spec.add_dependency "flat_pack"'
    refute_includes gemspec, 'spec.add_dependency "view_component"'
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_embargo.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-gem-template", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_verified_4x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"'
    refute_includes gemfile, 'tag: "v4.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.15.0"'
    refute_includes gemfile, 'tag: "v0.10.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.8.0"'
    refute_includes gemfile, 'tag: "v0.6.0"'
    refute_includes gemfile, 'tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", ref: "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"'
    assert_includes gemfile, 'gem "view_component", "4.19.0"'
    refute_includes gemfile, 'tag: "v0.1.240"'
    refute_includes gemfile, 'tag: "v0.1.196"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v4.4.0"'
    refute_includes gemfile, 'tag: "v4.3.0"'
    refute_includes gemfile, 'tag: "v4.2.2"'
    refute_includes gemfile, 'tag: "v4.2.1"'
    refute_includes gemfile, 'tag: "v4.2.0"'
    refute_includes gemfile, 'tag: "v0.9.1"'
    refute_includes gemfile, 'tag: "v0.5.0"'
    refute_includes gemfile, 'tag: "v0.1.177"'
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20260911024811_add_depends_on_recording_id_to_recording_studio_accesses.rb",
        __dir__
      )
    )

    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, "index_recording_studio_accesses_on_depends_on_recording_id"
    assert_includes migration, "add_column :recording_studio_accesses, :depends_on_recording_id, :uuid"
    assert_includes schema, 'create_table "recording_studio_access_invitations"'
    assert_includes schema, "idx_rs_access_invitations_token_digest"
    invitation_migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20261001000011_create_recording_studio_access_invitations.rb",
        __dir__
      )
    )
    assert_includes invitation_migration, "create_table :recording_studio_access_invitations"
    assert_includes schema, 't.string "role", default: "view", null: false'
    refute_includes schema, 't.integer "role", default: 0, null: false'
    role_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_change_recording_studio_accesses_role_to_string.rb", __dir__)
    ).max
    assert role_migration, "expected role-column migration in dummy db/migrate"
    assert_includes File.read(role_migration), "change_column :recording_studio_accesses, :role, :string"

    assert_includes schema, 'create_table "recording_studio_access_constraints"'
    assert_includes schema, 'create_table "recording_studio_access_rules"'
    assert_includes schema, "index_recording_studio_access_constraints_on_action"
    assert_includes schema, "index_recording_studio_access_rules_on_action"
    constraint_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_constraints.rb", __dir__)
    ).max
    rule_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_rules.rb", __dir__)
    ).max
    assert constraint_migration, "expected access constraints migration in dummy db/migrate"
    assert rule_migration, "expected access rules migration in dummy db/migrate"
    assert_includes File.read(constraint_migration), "create_table :recording_studio_access_constraints"
    assert_includes File.read(rule_migration), "create_table :recording_studio_access_rules"
  end

  def test_template_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_embargo/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_embargo/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_embargo/services/example_service.rb", __dir__))
  end

  def test_embargo_capability_wraps_include_for_and_is_not_enabled_globally
    source = File.read(File.expand_path("../lib/recording_studio/capabilities/embargo.rb", __dir__))

    assert_includes source, "def self.to(actions: [], manage_role: :edit)"
    assert_includes source, "RecordingStudio::Capabilities.include_for(:embargo, **options)"
    refute_includes source, "enable_capability"
    refute_includes source, "set_capability_options"
    assert_empty RecordingStudio.configuration.enabled_recordable_types_for(:embargo)
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "recording_studio_layout { devise_controller? ? \"application\" : nil }"
    refute_includes controller_source, "UsesDefaultLayout"
    refute_includes controller_source, "recording_studio/default_layout"
    refute_includes controller_source, "recording_studio/action_layout"
    switchable = File.read(File.expand_path("dummy/config/initializers/recording_studio_root_switchable.rb", __dir__))
    assert_includes switchable, 'config.layout = "recording_studio/default_layout"'
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/rich_text"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/engines/flat_pack/app/components"
    assert_includes tailwind_source, "../../../vendor/engines/recording_studio/app/views"
    refute_includes tailwind_source, "vendor/bundle/**/flatpack/app/components"
    refute_includes tailwind_source, "recordingstudio-*"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"

    head_partial = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )
    assert_includes head_partial, 'stylesheet_link_tag "flat_pack/application"'

    rake_task = File.read(File.expand_path("dummy/lib/tasks/tailwindcss.rake", __dir__))
    assert_includes rake_task, "FlatPack::Engine.root"
    assert_includes rake_task, "RecordingStudio::Engine.root"
    assert_includes rake_task, "tailwindcss:link_engine_sources"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, "config.recordable_types = [ \"Workspace\", \"Folder\", \"Page\" ]"
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source,
                    "This Rails app exists to validate Recording Studio Embargo in a real host application"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "redirects to `/`"
    refute_includes readme_source, "flat_pack_sidebar"
  end

  def test_product_readme_is_the_template_guide
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudio"
    assert_includes readme, "dummy GitHub tag `v6.1.0`"
    assert_includes readme, "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"
    refute_includes readme, "dummy GitHub tag `v4.5.0`"
    refute_includes readme, "dummy GitHub tag `v0.1.240`"
    refute_includes readme, "dummy GitHub tag `v0.1.196`"
    assert_includes readme, "dummy GitHub tag `v0.15.0`"
    refute_includes readme, "dummy GitHub tag `v0.10.1`"
    assert_includes readme, "dummy GitHub tag `v0.8.0`"
    refute_includes readme, "dummy GitHub tag `v0.6.0`"
    refute_includes readme, "dummy GitHub tag `v0.5.1`"
    refute_includes readme, "dummy GitHub tag `v4.4.0`"
    refute_includes readme, "dummy GitHub tag `v4.3.0`"
    refute_includes readme, "dummy GitHub tag `v4.2.2`"
    refute_includes readme, "dummy GitHub tag `v4.2.1`"
    refute_includes readme, "dummy GitHub tag `v4.2.0`"
    refute_includes readme, "v0.1.177"
    refute_includes readme, "v0.9.1"
    refute_includes readme, "v0.5.0"
    refute_includes readme, "v0.1.133"
    refute_includes readme, "v3 declarations"
    refute_includes readme, "RecordingStudio v3"
    refute_includes readme, "ExampleService"
    refute_includes readme, "recording_studio/v3.0.0"
  end

  def test_dummy_home_page_uses_demo_title_only
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, 'title: "Embargo"'
    assert_includes view_source, 'id="embargo-host-actions"'
    assert_includes view_source, "recording_studio_embargo_management_path("
    assert_includes view_source, "embargoed?(@page_recording)"
    assert_includes view_source, 'text: "More"'
    assert_includes view_source, 'id: "embargo-full-page-link"'
    assert_includes view_source, "render_embargo_notice(@page_recording"
    assert_includes view_source, "FlatPack::Modal::Component"
    assert_includes view_source, 'turbo_frame_tag "embargo_editor"'
    assert_includes view_source, "turbo_stream_from @page_recording"
    refute_includes view_source, "render_embargo_button"
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "dummy_page_nav"
    refute_includes view_source, 'title: "Demo"'
    refute_includes view_source, "variant: :h1"
    refute_includes view_source, "style: :default"
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav"
      assert_includes view_source, "subtitle:"
      refute_includes view_source, "variant: :h1"
      refute_includes view_source, "FlatPack::PageTitle::Component"
      refute_includes view_source, "FlatPack::Card::Component"
      refute_includes view_source, "FlatPack::Breadcrumb::Component"
    end

    methods_view = File.read(File.expand_path("dummy/app/views/docs/methods.html.erb", __dir__))
    assert_includes methods_view, "FlatPack::SectionTitle::Component"
    assert_includes methods_view, "FlatPack::CodeBlock::Component"

    gem_views_view = File.read(File.expand_path("dummy/app/views/docs/gem_views.html.erb", __dir__))
    assert_includes gem_views_view, "FlatPack::Table::Component"
    refute_includes gem_views_view, "FlatPack::List::Component"

    recordable_types_view = File.read(File.expand_path("dummy/app/views/docs/recordable_types.html.erb", __dir__))
    assert_includes recordable_types_view, "FlatPack::List::Component"
    refute_includes recordable_types_view, "v3 parent/root"

    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_dummy_recordings_tree_view_omits_structure_section_copy
    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))

    assert_includes recordings_tree_view, 'title: "Recordings tree"'
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    recording_tree_partial = File.read(File.expand_path("dummy/app/views/docs/_recording_tree_node.html.erb", __dir__))
    assert_includes recording_tree_partial, "parent_builder.node"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_embargo/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end
end
