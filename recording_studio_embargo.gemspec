# frozen_string_literal: true

require_relative "lib/recording_studio_embargo/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_embargo"
  spec.version     = RecordingStudioEmbargo::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_embargo"
  spec.summary     = "Time-based embargoes for Recording Studio recordings"
  spec.description = "A Recording Studio capability that temporarily restricts named actions " \
                     "until a release time, using Accessible audiences for early access."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_embargo"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_embargo/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
