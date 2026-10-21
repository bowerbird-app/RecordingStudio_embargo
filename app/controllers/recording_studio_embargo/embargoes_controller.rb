# frozen_string_literal: true

module RecordingStudioEmbargo
  class EmbargoesController < ApplicationController
    include RecordingStudio::UsesDefaultLayout if defined?(RecordingStudio::UsesDefaultLayout)

    before_action :require_signed_in_actor
    before_action :set_recording
    before_action :set_return_to

    def edit
      authorize_editor!
      return if performed?

      assign_editor
      render_editor if frame_request?
    end

    def update
      authorize_editor!
      return if performed?

      @recording.embargo_set!(embargo_params, actor: editor_actor)
      save_succeeded
    rescue Invalid => e
      save_failed(e)
    end

    private

    def require_signed_in_actor
      authenticate_user! if respond_to?(:authenticate_user!, true)
    end

    def set_recording
      @recording = RecordingStudio::Recording.find_by(id: params[:recording_id])
      return if @recording && capability_enabled?

      head :not_found
    end

    def capability_enabled?
      RecordingStudio.capability_enabled?(:embargo, for: @recording.recordable_type)
    end

    def authorize_editor!
      return if RecordingStudioEmbargo.configuration.authorize_management?(
        recording: @recording,
        actor: editor_actor,
        controller: self
      )

      head :forbidden
    end

    def editor_actor
      RecordingStudioEmbargo.configuration.actor_for(controller: self)
    end

    def assign_editor(submitted: false)
      @embargo = submitted ? submitted_embargo : current_or_new_embargo
      @editor = Editor.new(recording: @recording, embargo: @embargo)
    end

    def current_or_new_embargo
      @recording.current_embargo || Embargo.new(
        enabled: false,
        time_zone: RecordingStudioEmbargo.configuration.default_time_zone,
        early_access: false
      )
    end

    def submitted_embargo
      parsed = Attributes.parse(parent_recording: @recording, raw: embargo_params)
      embargo = current_or_new_embargo
      embargo.apply_configuration!(parsed)
      embargo
    rescue Invalid
      current_or_new_embargo
    end

    def embargo_params
      params.require(:embargo).permit(:enabled, :lifts_at, :time_zone, :early_access).to_h
    end

    def save_succeeded
      return refresh_page if frame_request?

      redirect_to after_save_location, notice: Copy.t("editor.saved")
    end

    def save_failed(error)
      assign_editor(submitted: true)
      flash.now[:alert] = error.message
      render_editor(status: :unprocessable_entity)
    end

    def refresh_page
      # Turbo drops a refresh tagged with the request that just finished.
      render turbo_stream: turbo_stream.refresh(request_id: nil, method: "morph", scroll: "preserve")
    end

    def after_save_location
      @return_to.presence || edit_recording_embargo_path(@recording)
    end

    def set_return_to
      @return_to = ReturnTo.path(params[:return_to], request: request)
    end

    def render_editor(**options)
      options[:layout] = false if frame_request?
      options[:formats] = [:html]
      render :edit, **options
    end

    def frame_request?
      return false unless respond_to?(:turbo_frame_request?, true)

      turbo_frame_request?
    end
  end
end
