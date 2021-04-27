# frozen_string_literal: true
class AbsoluteIdCreateSessionJob < ApplicationJob
  def perform(session_attributes:, user_id:)
    @user_id = user_id
    create_session(session_attributes)
  end

  private

  def create_session(session_attributes)
    @batches = session_attributes.map do |batch_params|
      model_id = AbsoluteIdCreateBatchJob.perform_now(properties: batch_params, user_id: @user_id)
      AbsoluteId::Batch.find(model_id)
    end

    return if @batches.empty?

    @session = AbsoluteId::Session.create(batches: @batches, user: current_user)
    @session.save!
    Rails.logger.info("Session created: #{@session.id}")
    @session.id
  end

  def current_user
    @current_user ||= User.find_by(id: @user_id)
  end

  def current_client
    @current_client ||= begin
                          source_client = LibJobs::ArchivesSpace::Client.source
                          source_client.login
                          source_client
                        end
  end
end
