module ApplicationHelper
  include RecordingStudioEmbargo::ApplicationHelper

  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home")
    content_for :title, title
    content_for :subtitle, subtitle if subtitle.present?

    nav = { round: true, style: :default }
    if back_url.present?
      nav[:back_href] = back_url
      nav[:back_tooltip] = back_label
    end
    flat_pack_page_nav(**nav)

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          url: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end
