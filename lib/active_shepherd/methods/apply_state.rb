class ActiveShepherd::Methods::ApplyState < ActiveShepherd::ApplyMethod
  def apply_state
    mark_all_associated_objects_for_destruction
    apply_default_state_to_root_model
    traverse!
  end

  def handle_attribute(attribute_name, raw_value)
    value = aggregate.deserialize_value attribute_name, raw_value
    aggregate.model.send "#{attribute_name}=", value
  end

  def handle_has_many_association(reflection, collection_state)
    association = aggregate.model.send reflection.name
    collection_state.each do |state|
      associated_model = association.build
      self.class.apply_state recurse(associated_model, reflection.foreign_key),
        state
    end
  end

  def handle_has_one_association(reflection, state)
    associated_model = aggregate.model.send "build_#{reflection.name}"
    self.class.apply_state recurse(associated_model, reflection.foreign_key),
      state
  end

private

  def apply_default_state_to_root_model
    default_attributes = aggregate.default_attributes
    ignored_attribute_names = attributes.keys.map(&:to_s) + aggregate.excluded_attributes

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

