class HomeController < ApplicationController
  def index
    page = Page.find_by(title: "Getting Started")
    @page_recording = page && RecordingStudio::Recording.find_by(recordable: page, trashed_at: nil)
  end
end
