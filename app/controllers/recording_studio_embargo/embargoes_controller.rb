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
    end

    def update
      authorize_editor!
      return if performed?

      @recording.embargo_set!(embargo_params, actor: editor_actor)
      redirect_to edit_recording_embargo_path(@recording), notice: Copy.t("editor.saved")
    rescue Invalid => e
      assign_editor(submitted: true)
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
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
        early_access: {}
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

    def early_access_param(access)
      return {} if access.blank?
      return access.to_unsafe_h if access.respond_to?(:to_unsafe_h)
      return access.to_h if access.respond_to?(:to_h)

      {}
    end

    def embargo_params
      raw = params.require(:embargo)
      permitted = raw.permit(:enabled, :lifts_at, :time_zone, :fallback).to_h
      permitted[:early_access] = early_access_param(raw[:early_access])
      permitted
    end
  end
end
