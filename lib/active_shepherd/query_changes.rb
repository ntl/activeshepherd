class ActiveShepherd::QueryChanges < ActiveShepherd::QueryMethod
  def query_changes
    {}.tap do |hash|
      hash.update get_create_or_destroy_keys
      hash.update get_changes_from_root_model
      hash.update get_changes_from_associations
    end
  end

private

  def get_changes_from_root_model
    aggregate.model.changes.each_with_object({}) do |(k,v),h|
      v_or_attribute = aggregate.model.attributes_before_type_cast[k]
      v.map! do |possible_serialized_value|
        aggregate.serialize_value(k, possible_serialized_value)
      end

      h[k.to_sym] = v unless aggregate.excluded_attributes.include?(k.to_s)
    end
  end

  def get_changes_from_associations
    aggregate.traversable_associations.each_with_object({}) do |(name, association_reflection), h|
      changes = get_changes_from_association association_reflection
      h[name.to_sym] = changes unless changes.blank?
    end
  end

  def get_changes_from_association(association_reflection)
    foreign_key_to_self = association_reflection.foreign_key
    send "get_changes_from_#{association_reflection.macro}_association",
      association_reflection.name, foreign_key_to_self
  end

  def get_changes_from_has_many_association(name, foreign_key)
    records = aggregate.model.send(name).each
    record_changes = records.with_object({}).with_index do |(associated_model, list), index|
      changes = get_changes_from_associated_model associated_model, foreign_key
      list[index] = changes unless changes.empty?
    end
    record_changes unless record_changes.empty?
  end

  def get_changes_from_has_one_association(name, foreign_key)
    associated_model = aggregate.model.send(name)
    return unless associated_model.present?

    changes = get_changes_from_associated_model associated_model, foreign_key
    changes unless changes.empty?
  end

  def get_changes_from_associated_model(model, foreign_key)
    ActiveShepherd::Aggregate.new(model, foreign_key).changes
  end

  def get_create_or_destroy_keys
    if not aggregate.model.persisted?
      { _create: '1' }
    elsif aggregate.model.marked_for_destruction?
      { _destroy: '1' }
    else
      {}
    end
  end
end
