# frozen_string_literal: true
class AbsoluteId::Session < ApplicationRecord
  include ActiveModel::Serializers::JSON
  has_many :batches, class_name: 'AbsoluteId::Batch', foreign_key: "absolute_id_session_id"
  belongs_to :user, foreign_key: "user_id"

  class CsvPresenter
    def self.headers
      ["ID", "User", "Barcode", "Location", "Container Profile", "Repository", "Call Number", "Box Number"]
    end

    def initialize(model)
      @model = model
    end

    def rows
      @rows ||= begin
                  batch_csv_tables = batches.map(&:csv_table)
                  batch_csv_tables.map(&:to_a).flatten
                end
    end

    def to_s
      CSV.generate(col_sep: ",") do |csv|
        csv << self.class.headers

        rows.each do |entry|
          location = "#{entry.location.building} (#{entry.location.uri})"
          container_profile = "#{entry.container_profile.name} (#{entry.container_profile.uri})"
          repository = "#{entry.repository.name} (#{entry.repository.uri})"
          resource = "#{entry.resource.title} (#{entry.resource.uri})"
          container = "#{entry.container.indicator} (#{entry.container.uri})"

          csv << [
            entry.label,
            entry.user,
            entry.barcode,
            location,
            container_profile,
            repository,
            resource,
            container
          ]
        end
      end
    end

    def table
      @table ||= begin
                   CSV::Table.new(rows)
                 end
    end
  end

  def self.xml_serializer
    AbsoluteIds::SessionXmlSerializer
  end

  def label
    format("Session %d (%s)", id, created_at.strftime('%m/%d/%Y'))
  end

  def synchronized?
    batches.map(&:synchronized?).reduce(&:&)
  end

  def synchronizing?
    batches.map(&:synchronizing?).reduce(&:|)
  end

  def synchronize_status
    values = batches.map(&:synchronize_status)

    if values.include?(AbsoluteId::SYNCHRONIZE_FAILED)
      AbsoluteId::SYNCHRONIZE_FAILED
    elsif values.include?(AbsoluteId::NEVER_SYNCHRONIZED)
      AbsoluteId::NEVER_SYNCHRONIZED
    elsif values.include?(AbsoluteId::UNSYNCHRONIZED)
      AbsoluteId::UNSYNCHRONIZED
    elsif values.include?(AbsoluteId::SYNCHRONIZING)
      AbsoluteId::SYNCHRONIZING
    else
      AbsoluteId::SYNCHRONIZED
    end
  end

  def absolute_ids
    @absolute_ids ||= batches.map(&:absolute_ids).flatten
  end

  def attributes
    {
      batches: batches.to_a.map(&:attributes)
    }
  end

  # @todo Determine why this is needed
  def as_json(_options = nil)
    attributes
  end

  def to_yaml
    YAML.dump(attributes)
  end

  def csv_table
    csv_presenter.table
  end
  delegate :to_csv, to: :csv_table

  # @see ActiveModel::Serializers::Xml
  def to_xml(options = {}, &block)
    self.class.xml_serializer.new(self, options).serialize(&block)
  end

  private

  def csv_presenter
    @csv_presenter ||= CsvPresenter.new(self)
  end
end
