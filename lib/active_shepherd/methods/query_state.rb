class ActiveShepherd::Methods::QueryState < ActiveShepherd::QueryMethod
  def query_state
    traverse!
    query
  end

  def handle_attribute(name, value)
    query[name] = value
  end

  def handle_has_many_association(reflection)
    association = aggregate.model.send reflection.name
    collection_state = association.map do |associated_model|
      recurse(associated_model, reflection.foreign_key).state
    end
    query[reflection.name] = collection_state unless collection_state.blank?
  end

  def handle_has_one_association(reflection)
    associated_model = aggregate.model.send reflection.name
    if associated_model
      state = recurse(associated_model, reflection.foreign_key).state
      query[reflection.name] = state unless state.blank?
    end
  end

  def setup
    super
    @attributes = aggregate.raw_attributes.each_with_object({}) do |(name,raw),h|
      next if aggregate.excluded_attributes.include? name
      value = aggregate.serialize_value name, raw
      unless value == aggregate.default_attributes[name]
        h[name.to_sym] = value
      end
    end
  end
end

