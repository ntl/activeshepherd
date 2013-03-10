class ActiveShepherd::Methods::QueryState < ActiveShepherd::QueryMethod
  def query_state
    {}.tap do |hash|
      hash.update get_state_from_root_model
      hash.update get_state_from_associations
    end
  end

private

  def get_state_from_root_model
    aggregate.raw_attributes.each_with_object({}) do |(name, value), h|
      next if aggregate.excluded_attributes.include?(name)
      value = aggregate.serialize_value(name, value)
      unless value == aggregate.default_attributes[name]
        h[name.to_sym] = value
      end
    end
  end

  def get_state_from_associations
    aggregate.traversable_associations.each_with_object({}) do |(name, association_reflection), h|
      state = get_state_from_association name, association_reflection
      h[name.to_sym] = state unless state.blank?
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
    state unless state.empty?
  end

  def get_state_from_has_one_association(name, foreign_key)
    associated_model = aggregate.model.send name
    if associated_model
      get_state_from_associated_model associated_model, foreign_key 
    end
  end

  def get_state_from_associated_model(model, foreign_key)
    ActiveShepherd::Aggregate.new(model, foreign_key).state
  end
end
