# frozen_string_literal: true
require 'rails_helper'

describe LibJobs::ArchivesSpace::Repository do
  subject(:repository) do
    described_class.new(client: client, id: id)
  end
  let(:client) { instance_double(LibJobs::ArchivesSpace::Client) }
  let(:id) { 'test-repository' }
  let(:top_container_id) { 'test-top-container-id' }
  let(:resource_id) { 'test-resource-id' }
  let(:resource_fixture_file_path) do
    Rails.root.join('spec', 'fixtures', 'archives_space_resource.json')
  end
  let(:resource_fixture_json) do
    File.read(resource_fixture_file_path)
  end
  let(:top_container_fixture_file_path) do
    Rails.root.join('spec', 'fixtures', 'archives_space_top_container.json')
  end
  let(:top_container_fixture_json) do
    File.read(top_container_fixture_file_path)
  end
  let(:top_container_response) { instance_double(::ArchivesSpace::Response) }
  let(:resource_response) { instance_double(::ArchivesSpace::Response) }

  before do
    allow(top_container_response).to receive(:body).and_return(top_container_fixture_json)
    allow(top_container_response).to receive(:status).and_return(200)

    allow(client).to receive(:get).with(
      "/repositories/test-repository/top_containers/#{top_container_id}"
    ).and_return(top_container_response)

    allow(resource_response).to receive(:body).and_return(resource_fixture_json)
    allow(resource_response).to receive(:status).and_return(200)

    allow(client).to receive(:get).with(
      "/repositories/test-repository/resources/#{resource_id}"
    ).and_return(resource_response)
  end

  describe '#find_resource' do
    it 'retrieves the ArchivesSpace Resource' do
      resource = repository.find_resource(id: resource_id)
      expect(resource).to be_a LibJobs::ArchivesSpace::Resource
      expect(resource.id).to eq(resource_id)
    end
  end

  describe '#find_top_container' do
    it 'retrieves the ArchivesSpace TopContainer' do
      top_container = repository.find_top_container(id: top_container_id)
      expect(top_container).to be_a LibJobs::ArchivesSpace::TopContainer
      expect(top_container.id).to eq(top_container_id)
    end
  end
end
