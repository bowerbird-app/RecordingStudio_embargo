# frozen_string_literal: true

require "rails/generators"

module RecordingStudioEmbargo
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install RecordingStudioEmbargo into a host application"

      class_option :mount_path, type: :string, default: "/recording_studio_embargo",
                                desc: "Route prefix used when mounting the engine"

      def mount_engine
        route %(mount RecordingStudioEmbargo::Engine, at: "#{options[:mount_path]}")
      end

      def copy_initializer
        template "recording_studio_embargo_initializer.rb", "config/initializers/recording_studio_embargo.rb"
      end

      def copy_configuration
        template "recording_studio_embargo.yml", "config/recording_studio_embargo.yml"
      end

      def add_tailwind_source
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        line = tailwind_source_line
        unless File.exist?(tailwind_css_path)
          say "Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow
          say "If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow
          say "  #{line}", :yellow
          return
        end

        contents = File.read(tailwind_css_path)
        return if contents.include?("recording_studio_embargo/app/views")

        unless contents.include?("@import \"tailwindcss\";")
          say "Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow
          say "Please manually add these lines to your Tailwind CSS config:", :yellow
          say "  #{line}", :yellow
          return
        end

        inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
          "\n#{line}\n"
        end
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def tailwind_source_line
        '@source "../../../lib/recording_studio_embargo/app/views/**/*.erb";'
      end
    end
  end
end
