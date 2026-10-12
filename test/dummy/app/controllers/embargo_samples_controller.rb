# frozen_string_literal: true

class EmbargoSamplesController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

  def show
    recording = RecordingStudio::Recording.find(params[:id])
    presentation = RecordingStudioEmbargo.presskit_presentation(
      recording: recording,
      actor: current_actor,
      view_action: :"pages.show",
      normal_fallback: :hidden
    )
    assign_embargo_cache!(recording, :"pages.show")
    render plain: presentation.to_s, status: (%i[full preview].include?(presentation) ? :ok : :not_found)
  end

  def download
    recording = RecordingStudio::Recording.find(params[:id])
    allowed = RecordingStudioEmbargo.action_permitted?(
      recording: recording,
      action: :"pages.download",
      actor: current_actor
    )
    assign_embargo_cache!(recording, :"pages.download")
    if allowed
      render plain: "DOWNLOAD_OK"
    else
      render plain: "DOWNLOAD_DENIED", status: :forbidden
    end
  end

  private

  def current_actor
    return current_user if respond_to?(:user_signed_in?) && user_signed_in?

    nil
  end

  def assign_embargo_cache!(recording, action)
    return unless recording.embargo_active?

    response.set_header("Cache-Control", "private, no-store")
    response.set_header("X-Embargo-Expires-In", RecordingStudioEmbargo.cache_expires_in(recording).to_i.to_s)
    response.set_header("X-Embargo-Cache-Key", RecordingStudioEmbargo.cache_key(recording, current_actor, action).join(":"))
  end
end
