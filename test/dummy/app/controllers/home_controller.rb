class HomeController < ApplicationController
  def index
    @page_recording = requested_recording || seeded_page_recording
  end

  private

  def requested_recording
    return if params[:recording_id].blank?

    RecordingStudio::Recording.find_by(id: params[:recording_id])
  end

  def seeded_page_recording
    page = Page.find_by(title: "Getting Started")
    page && RecordingStudio::Recording.find_by(recordable: page, trashed_at: nil)
  end
end
