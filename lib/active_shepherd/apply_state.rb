class ActiveShepherd::ApplyState
  attr_reader :aggregate, :hash

  def initialize(aggregate, hash)
    @aggregate = aggregate
    @hash      = hash.dup
  end

  def apply_state
    mark_all_associated_objects_for_destruction
    apply_default_state_to_root_model
    apply_state_to_root_model
    apply_state_to_associations
  end

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
    keys[:attributes].each do |attribute_name|
      value = aggregate.deserialize_value attribute_name, hash[attribute_name]
      aggregate.model.send "#{attribute_name}=", value
    end
  end

  def apply_state_to_associations
    keys[:associations].each do |association_name|
      association_reflection = aggregate.traversable_associations[association_name]
      apply_state_to_association association_reflection, hash[association_name]
    end
  end

private

  def keys
    @keys ||= begin
      keys_hash = { attributes: [], associations: [] }
      hash.keys.each_with_object(keys_hash) do |key_name, keys|
        if aggregate.traversable_associations.keys.include? key_name
          keys[:associations] << key_name
        elsif aggregate.untraversable_associations.keys.include? key_name
        else
          keys[:attributes] << key_name
        end
      end
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

  def apply_state_to_association(association_reflection, state)
    foreign_key_to_self = association_reflection.foreign_key

    send "apply_state_to_#{association_reflection.macro}_association",
      association_reflection, foreign_key_to_self, state
  end

  def apply_state_to_has_many_association(association_reflection, foreign_key, state_set)
    association = aggregate.model.send(association_reflection.name)

    state_set.each do |state|
      associated_model = association.build

      ActiveShepherd::Aggregate.new(associated_model, foreign_key).state = state
    end
  end

  def apply_state_to_has_one_association(association_reflection, foreign_key, state)
    associated_model = aggregate.model.send("build_#{association_reflection.name}")

    ActiveShepherd::Aggregate.new(associated_model, foreign_key).state = state
  end
end
