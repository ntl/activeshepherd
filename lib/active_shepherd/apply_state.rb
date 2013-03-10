class ActiveShepherd::ApplyState < ActiveShepherd::StateMethod
  def apply_state
    mark_all_associated_objects_for_destruction
    apply_default_state_to_root_model
    apply_state_to_root_model
    apply_state_to_associations
  end

private

  def apply_default_state_to_root_model
    default_attributes = aggregate.default_attributes
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
  end

  def apply_state_to_root_model
    attributes.each do |attribute_name, raw_value|
      value = aggregate.deserialize_value attribute_name, raw_value
      aggregate.model.send "#{attribute_name}=", value
    end
  end

  def apply_state_to_associations
    associations.values.each do |association_reflection, state|
      apply_state_to_association association_reflection, state
    end
  end

  def apply_state_to_association(association_reflection, state)
    foreign_key_to_self = association_reflection.foreign_key

    send "apply_state_to_#{association_reflection.macro}_association",
      association_reflection, foreign_key_to_self, state
  end

  def apply_state_to_has_many_association(association_reflection, foreign_key, state_set)
    association = aggregate.model.send(association_reflection.name)
    state_set.each do |state|
      associated_model = association.build
      apply_state_to_associated_model associated_model, foreign_key, state
    end
  end

  def apply_state_to_has_one_association(association_reflection, foreign_key, state)
    associated_model = aggregate.model.send("build_#{association_reflection.name}")
    apply_state_to_associated_model associated_model, foreign_key, state
  end

  def apply_state_to_associated_model(associated_model, foreign_key, state)
    ActiveShepherd::Aggregate.new(associated_model, foreign_key).state = state
  end

  def mark_all_associated_objects_for_destruction
    aggregate.traversable_associations.each do |name, association_reflection|
      if association_reflection.macro == :has_many
        aggregate.model.send(name).each { |record| record.mark_for_destruction }
      elsif association_reflection.macro == :has_one
        aggregate.model.send(name).try(&:mark_for_destruction)
      end
    end
  end
end
