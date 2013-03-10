class ActiveShepherd::ApplyState
  attr_reader :aggregate, :hash

  def initialize(aggregate, hash)
    @aggregate = aggregate
    @hash      = hash
  end

  def apply_state
    mark_all_associated_objects_for_destruction

    default_attributes = aggregate.model.class.new.attributes
    ignored_attribute_names = hash.keys.map(&:to_s) + aggregate.excluded_attributes

    (default_attributes.keys - ignored_attribute_names).each do |attribute_name|
      current_value = aggregate.model.attributes[attribute_name]
      default_value = default_attributes[attribute_name]

      unless aggregate.deserialize_value(attribute_name, default_value) == default_value
        raise 'Have not handled this use case yet; serialized attributes with a default value'
      end

      next if default_value == current_value

      aggregate.model.send("#{attribute_name}=", default_value)
    end

    association_reflections = aggregate.traversable_associations

    hash.each do |attribute_or_association_name, value|
      association_reflection = association_reflections[attribute_or_association_name]

      if association_reflection.present?
        set_via_association(association_reflection, value)
      elsif aggregate.untraversable_associations.keys.include? attribute_or_association_name
      else
        attribute_name = attribute_or_association_name
        setter = "#{attribute_name}="
        aggregate.model.send(setter, aggregate.deserialize_value(attribute_name, value))
      end
    end
  end

private

  def mark_all_associated_objects_for_destruction
    aggregate.traversable_associations.each do |name, association_reflection|
      if association_reflection.macro == :has_many
        aggregate.model.send(name).each { |record| record.mark_for_destruction }
      elsif association_reflection.macro == :has_one
        aggregate.model.send(name).try(&:mark_for_destruction)
      end
    end
  end

  def set_via_association(association_reflection, value)
    foreign_key_to_self = association_reflection.foreign_key

    if association_reflection.macro == :has_many
      association = aggregate.model.send(association_reflection.name)

      value.each do |hash|
        associated_model = association.build

        ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).state = hash
      end
    elsif association_reflection.macro == :has_one
      associated_model = aggregate.model.send("build_#{association_reflection.name}")

      ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).state = value
    end
  end
end
