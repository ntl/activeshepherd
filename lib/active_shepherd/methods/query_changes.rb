class ActiveShepherd::Methods::QueryChanges < ActiveShepherd::QueryMethod
  def query_changes
    traverse!
    set_meta_action
    query
  end

  def handle_attribute(attribute_name, before, after)
    query[attribute_name] = [before, after]
  end

  def handle_has_many_association(reflection)
    association = aggregate.model.send reflection.name

    collection_changes = association.each.with_object({}).with_index do |(associated_model, h), index|
      changes = recurse(associated_model, reflection.foreign_key).changes
      h[index] = changes unless changes.blank?
    end

    unless collection_changes.blank?
      query[reflection.name] = collection_changes
    end
  end

  def handle_has_one_association(reflection)
    associated_model = aggregate.model.send reflection.name
    return unless associated_model.present?

    changes = recurse(associated_model, reflection.foreign_key).changes
    query[reflection.name] = changes unless changes.blank?
  end

  def setup
    super
    @attributes = aggregate.model.changes.each_with_object({}) do |(name,changes),h|
      next if aggregate.excluded_attributes.include? name.to_s
      h[name.to_sym] = changes.map do |raw_value|
        aggregate.serialize_value name, raw_value
      end
    end
  end

private

  def set_meta_action
    if not aggregate.model.persisted?
      query[:_create] = '1'
    elsif aggregate.model.marked_for_destruction?
      query[:_destroy] = '1'
    end
  end
end

