# frozen_string_literal: true

require "test_helper"

class ReturnToTest < Minitest::Test
  Request = Struct.new(:scheme, :host, :port)

  def test_relative_paths_are_kept
    assert_equal "/kits/1", path("/kits/1")
    assert_equal "/kits/1?tab=more#embargo", path("/kits/1?tab=more#embargo")
    assert_equal "/kits/1", path("  /kits/1  ")
  end

  def test_same_origin_absolute_urls_become_a_path
    assert_equal "/kits/1?x=1", path("http://example.com/kits/1?x=1")
    assert_equal "/", path("http://example.com")
    assert_equal "/kits/1", path("https://example.com/kits/1", scheme: "https", port: 443)
  end

  def test_other_origins_and_schemes_are_dropped
    assert_nil path("https://evil.test/kits")
    assert_nil path("https://example.com/kits")
    assert_nil path("//evil.test/kits")
    assert_nil path("javascript:alert(1)")
    assert_nil path("http://example.com:444/kits", port: 80)
    assert_nil path("https://example.com.evil.test/kits")
    assert_nil path("/\\evil.test")
    assert_nil path("\\\\evil.test")
    assert_nil path("/kits\nSet-Cookie:x")
    assert_nil path("")
    assert_nil path(nil)
  end

  private

  def path(candidate, scheme: "http", host: "example.com", port: 80)
    RecordingStudioEmbargo::ReturnTo.path(candidate, request: Request.new(scheme, host, port))
  end
end
