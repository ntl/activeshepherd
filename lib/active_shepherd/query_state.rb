class ActiveShepherd::QueryState < ActiveShepherd::StateMethod
  def query_state
    get_state_from_root_model
    get_state_from_associations
    hash
  end

private

  def get_state_from_root_model
    aggregate.model.attributes_before_type_cast.each do |attribute_name, value|
      next if aggregate.excluded_attributes.include?(attribute_name)

      value = aggregate.serialize_value(attribute_name, value)

      unless value == aggregate.default_attributes[attribute_name]
        hash[attribute_name.to_sym] = value
      end
    end
  end

  def get_state_from_associations
    aggregate.traversable_associations.each do |name, association_reflection|
      get_state_from_association name, association_reflection
    end
  end

  def get_state_from_association(name, association_reflection)
    foreign_key_to_self = association_reflection.foreign_key
    send "get_state_from_#{association_reflection.macro}_association",
      association_reflection.name, foreign_key_to_self
  end

  def get_state_from_has_many_association(name, foreign_key)
    state = aggregate.model.send(name).map do |associated_model|
      get_state_from_associated_model associated_model, foreign_key
    end
    hash[name] = state unless state.empty?
  end

  def get_state_from_has_one_association(name, foreign_key)
    associated_model = aggregate.model.send name
    if associated_model
      hash[name] = get_state_from_associated_model associated_model, foreign_key 
    end
  end

  def get_state_from_associated_model(model, foreign_key)
    ActiveShepherd::Aggregate.new(model, foreign_key).state
  end
end
