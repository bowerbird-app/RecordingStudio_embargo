# frozen_string_literal: true

RecordingStudioEmbargo::Engine.routes.draw do
  root "home#index"
  get "recordings/:recording_id/embargo/edit", to: "embargoes#edit", as: :edit_recording_embargo
  patch "recordings/:recording_id/embargo", to: "embargoes#update", as: :recording_embargo
end
