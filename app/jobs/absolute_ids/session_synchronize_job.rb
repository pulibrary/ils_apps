# frozen_string_literal: true
module AbsoluteIds
  class SessionSynchronizeJob < BaseJob
    queue_as :default
    class SynchronizeError < StandardError; end
    class DuplicateBarcodeError < SynchronizeError; end
    class DuplicateIndicatorError < SynchronizeError; end

    class ClientMapper
      def self.root_config_file_path
        Rails.root.join('config', 'archives_space', 'mapper')
      end

      def self.sync_config_file_path
        root_config_file_path.join('sync.yml')
      end

      def self.sync_config_erb
        io_stream = IO.read(sync_config_file_path)
        erb_document = ERB.new(io_stream)
        erb_document.result(binding)
      end

      def self.sync_config
        parsed = YAML.safe_load(sync_config_erb)
        OpenStruct.new(**parsed.symbolize_keys)
      rescue StandardError, SyntaxError => e
        raise("#{yaml_file_path} was found, but could not be parsed: \n#{e.inspect}")
      end

      # This is not used
      def source_client
        @source_client ||= begin
                            client = LibJobs::ArchivesSpace::Client.source
                            client.login
                            client
                          end
      end

      def sync_client
        @sync_client ||= begin
                          client = LibJobs::ArchivesSpace::Client.sync
                          client.login
                          client
                        end
      end
    end

    def client_mapper
      @client_mapper ||= ClientMapper.new
    end

    # Ensure that the barcode is unique
    # @param barcode
    # @param indicator
    # @param repository
    # @return [Array<TopContainer>]
    def validate_unique_barcode(barcode:, repository:, container_id:)
      top_resources = repository.search_top_containers_by(barcode: barcode.value)
      top_resource_ids = top_resources.map(&:id)

      unless top_resource_ids.include?(container_id) || top_resources.empty?
        raise(DuplicateBarcodeError, "Failed to synchronize #{absolute_id.label} ArchivesSpace: the barcode #{barcode.value} is not unique")
      end
    end

    # Ensure that the indicator is unique
    # @param barcode
    # @param indicator
    # @param repository
    # @return [Array<TopContainer>]
    def validate_unique_indicator(indicator:, repository:, container_id:)
      top_resources = repository.search_top_containers_by(indicator: indicator)
      top_resource_ids = top_resources.map(&:id)

      unless top_resource_ids.include?(container_id) || top_resources.empty?
        raise(DuplicateIndicatorError, "Failed to synchronize #{absolute_id.label} ArchivesSpace: the Absolute ID #{absolute_id.label} is not unique")
      end
    end

    def update_container_profile(uri: container.id, container_profile_uri: container_profile.uri)
      # batch_update_top_containers(containers:, container_profile_uri: nil, location_uri: nil)
    end

    def update_location(uri: container.id, location_uri: location.uri)
      # batch_update_top_containers(containers:, container_profile_uri: nil, location_uri: nil)
    end

    # Update the TopContainer
    # @param uri
    # @param barcode
    # @param indicator
    # @param location
    def update_top_container(uri:, barcode:, indicator:, location:)
      source_client = client_mapper.source_client
      source_repository = source_client.find_repository_by(uri: repository.uri)
      source_container = source_repository.find_top_container_by(uri: uri)
      raise(SynchronizeError, "Failed to locate the container resource for #{uri}") if source_container.nil?

      current_locations = container.container_locations
      source_location = source_client.find_location_by(uri: location.uri)
      raise(SynchronizeError, "Failed to locate the location resource for #{location.uri}") if source_location.nil?

      updated_locations = current_locations.map { |location_attrs| LibJobs::ArchivesSpace::Location.new(location_attrs) }.reject do |location_model|
        location_model.uri.to_s == source_location.uri.to_s
      end

      sync_client = client_mapper.sync_client
      sync_repository = sync_client.find_repository_by(uri: source_repository.uri)
      sync_container = sync_repository.find_top_container_by(uri: source_container.uri)

      # Verify that the AbID and barcode are unique for the TopContainer
      validate_unique_barcode(barcode: barcode, repository: sync_repository, container_id: sync_container.id)
      validate_unique_indicator(indicator: indicator, repository: sync_repository, container_id: sync_container.id)

      updated = sync_container.update(barcode: barcode.value, indicator: indicator, container_locations: updated_locations)
      Rails.logger.warn("Failed to update the TopContainer: #{sync_container.uri}") if updated.nil?

      # Update the container profile
      updated_with_profile = sync_repository.batch_update_top_containers(containers: [sync_container], container_profile_uri: container_profile.uri)
      Rails.logger.warn("Failed to update the TopContainer #{sync_container.uri} with the ContainerProfile #{container_profile.uri}") if updated_with_profile.empty?

      # Update the location
      updated_with_location = sync_repository.batch_update_top_containers(containers: [sync_container], location_uri: location.uri)
      Rails.logger.warn("Failed to update the TopContainer #{sync_container.uri} with the Location #{location.uri}") if updated_with_location.empty?

      updated_with_location.first
    end

    def perform(user_id:, model_id:)
      @user_id = user_id
      @model_id = model_id

      return if container.to_h.empty?
      return if location.to_h.empty?

      begin
        absolute_id.synchronizing = true
        absolute_id.synchronize_status = AbsoluteId::SYNCHRONIZING
        absolute_id.save!

        update_top_container(uri: container.uri, barcode: absolute_id.barcode, indicator: absolute_id.label, location: location)

        absolute_id.synchronized_at = DateTime.current
        absolute_id.synchronize_status = AbsoluteId::SYNCHRONIZED
        absolute_id.save!
      rescue DuplicateBarcodeError
        Rails.logger.warn("Warning: Failed to synchronize #{absolute_id.label}: Barcode #{absolute_id.barcode.value} is already used in ArchivesSpace.")

        absolute_id.synchronize_status = AbsoluteId::SYNCHRONIZE_FAILED
        absolute_id.save!
      rescue LibJobs::ArchivesSpace::UpdateRecordError => update_record_error
        Rails.logger.warn("Warning: Failed to synchronize #{absolute_id.label}: #{update_record_error}")

        absolute_id.synchronize_status = AbsoluteId::SYNCHRONIZE_FAILED
        absolute_id.save!
      rescue StandardError => error
        Rails.logger.warn("Warning: Failed to synchronize #{absolute_id.label}: #{error}")

        absolute_id.synchronize_status = AbsoluteId::SYNCHRONIZE_FAILED
        absolute_id.save!
      end

      absolute_id.synchronizing = false
      absolute_id.save!
      absolute_id
    end

    private

    def user
      @user ||= User.find(@user_id)
    end

    def absolute_id
      @absolute_id ||= AbsoluteId.find_by(id: @model_id)
    end

    def container
      absolute_id.container_object
    end

    def location
      absolute_id.location_object
    end

    def container_profile
      absolute_id.container_profile_object
    end

    def repository
      absolute_id.repository_object
    end
  end
end
