# frozen_string_literal: true

module RecordingStudioEmbargo
  class EmbargoesController < ApplicationController
    include RecordingStudio::UsesDefaultLayout if defined?(RecordingStudio::UsesDefaultLayout)

    before_action :require_signed_in_actor
    before_action :set_recording

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
      return render_frame_save if frame_request?

      redirect_to edit_recording_embargo_path(@recording), notice: Copy.t("editor.saved")
    end

    def save_failed(error)
      assign_editor(submitted: true)
      flash.now[:alert] = error.message
      render_editor(status: :unprocessable_entity)
    end

    def render_frame_save
      @recording.reload
      assign_editor
      flash.now[:notice] = Copy.t("editor.saved")
      respond_to do |format|
        format.turbo_stream
        format.html { render_editor }
      end
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
