# frozen_string_literal: true

require "uri"

module RecordingStudioEmbargo
  # A host may send the visitor back after a full-page save. Only a same-origin
  # path is accepted. Anything else is dropped and the caller picks a default.
  module ReturnTo
    module_function

    def path(candidate, request:)
      raw = candidate.to_s.strip
      return if raw.blank?
      return if raw.match?(/[[:cntrl:]\\]/)

      uri = URI.parse(raw)
      return relative_path(raw, uri) if uri.relative? && uri.host.nil?

      absolute_path(uri, request)
    rescue URI::InvalidURIError, URI::InvalidComponentError
      nil
    end

    def relative_path(raw, uri)
      return if raw.start_with?("//")
      return unless raw.start_with?("/")

      compose(uri)
    end

    def absolute_path(uri, request)
      return unless request
      return unless %w[http https].include?(uri.scheme)
      return unless uri.scheme == request.scheme
      return unless uri.host == request.host
      return unless uri.port == request.port

      compose(uri)
    end

    def compose(uri)
      path = uri.path.presence || "/"
      path = "#{path}?#{uri.query}" if uri.query.present?
      path = "#{path}##{uri.fragment}" if uri.fragment.present?
      path
    end
    private_class_method :relative_path, :absolute_path, :compose
  end
end
