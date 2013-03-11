class ActiveShepherd::Aggregate
  attr_reader :excluded_attributes
  attr_reader :model

  def initialize(model, excluded_attributes = [])
    @model = model

    @excluded_attributes = ["id", "created_at", "updated_at"]
    @excluded_attributes.concat(Array.wrap(excluded_attributes).map(&:to_s))
  end

  def default_attributes
    model.class.new.attributes
  end

  def raw_attributes
    model.attributes_before_type_cast
  end

  def traversable_associations
    associations.traversable
  end

  def untraversable_association_names
    associations.untraversable.keys
  end

  def serialize_value(attribute_name, value)
    run_through_serializer(attribute_name, value, :dump)
  end

  def deserialize_value(attribute_name, value)
    run_through_serializer(attribute_name, value, :load)
  end

private

  def associations
    @associations ||= begin
      all_associations = model.class.reflect_on_all_associations
      ostruct = OpenStruct.new untraversable: {}, traversable: {}
      all_associations.each_with_object(ostruct) do |association_reflection, ostruct|
        if traverse_association?(association_reflection)
          key = :traversable
        else
          key = :untraversable
        end
        ostruct.send(key)[association_reflection.name] = association_reflection
      end
    end
  end

  def run_through_serializer(attribute_name, value, method)
    serializer = model.class.serialized_attributes[attribute_name.to_s]
    if serializer
      serializer.send(method, value)
    else
      value
    end
  end

  def traverse_association?(association)
    return false if association.options[:readonly]
    return false if association.macro == :belongs_to

    true
  end

end
