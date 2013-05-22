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

  def in_namespace?(name)
    my_namespace = model.class.to_s
    if name == my_namespace
      false
    elsif name.deconstantize == my_namespace
      true
    elsif name.deconstantize == my_namespace.deconstantize && !name.deconstantize.blank?
      true
    else
      false
    end
  end

private

  def associations
    @associations ||= begin
      ostruct = OpenStruct.new untraversable: {}, traversable: {}
      associations_by_table.each_with_object(ostruct) do |(table, associations), ostruct|
        association_reflection = preferred_association_from_set associations
        if traverse_association?(association_reflection)
          key = :traversable
        else
          key = :untraversable
        end
        ostruct.send(key)[association_reflection.name] = association_reflection
      end
    end
  end

  def associations_by_table
    @associations_by_table ||=
      begin
        by_table = Hash.new { |h,k| h[k] = Array.new }
        model.class.reflect_on_all_associations.each do |association_reflection, hash|
          next unless association_reflection.active_record == model.class
          if traverse_association? association_reflection
            by_table[association_reflection.table_name] << association_reflection
          end
        end
        by_table
      end
  end

  def preferred_association_from_set(associations)
    associations.detect { |a| a.macro == :has_many } || associations.first
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
    return false unless in_namespace?(association.klass.to_s)
    return false if association.is_a?(ActiveRecord::Reflection::ThroughReflection)

    true
  end

end
