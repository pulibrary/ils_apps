class AbsoluteId::Batch < ApplicationRecord
  include ActiveModel::Serializers::JSON
  has_many :absolute_ids
  belongs_to :session, class_name: 'AbsoluteId::Session', optional: true
  belongs_to :user

  def label
    format("Batch %06d", id)
  end

  def synchronized?
    absolute_ids.map(&:synchronized?).reduce(&:&)
  end

  def synchronizing?
    absolute_ids.map(&:synchronizing?).reduce(&:|)
  end

  def table_data
    absolute_ids.map do |absolute_id|
      {
        user: user.email,
        barcode: absolute_id.barcode.value,
        label: absolute_id.label,
        location: { link: absolute_id.location_object.uri, value: absolute_id.location_object.building },
        container_profile: { link: absolute_id.container_profile_object.uri, value: absolute_id.container_profile_object.name },
        repository: { link: absolute_id.repository_object.uri, value: absolute_id.repository_object.name },
        resource: { link: absolute_id.resource_object.uri, value: absolute_id.resource_object.title },
        container: { link: absolute_id.container_object.uri, value: absolute_id.container_object.indicator },
        synchronized_at: absolute_id.synchronized_at || 'Never'
      }
    end
  end

  def attributes
    {
      id: id,
      label: label,
      tableData: table_data
    }
  end

  def as_json(options = nil)
    JSON.generate(attributes)
  end

  def self.xml_serializer
    AbsoluteIds::BatchXmlSerializer
  end

  # @see ActiveModel::Serializers::Xml
  def to_xml(options = {}, &block)
    self.class.xml_serializer.new(self, options).serialize(&block)
  end
end
