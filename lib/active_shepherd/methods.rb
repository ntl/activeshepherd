class ActiveShepherd::Methods
  class ApplyChanges < ActiveShepherd::ApplyMethod
    def apply_changes
      handle_create_or_destroy_keys
      traverse!
    end

    def handle_attribute(attribute_name, before_and_after)
      before, after = before_and_after
      current_value = aggregate.model.send(attribute_name)

      before = aggregate.deserialize_value(attribute_name, before)
      after  = aggregate.deserialize_value(attribute_name, after)

      unless current_value == before
        raise ::ActiveShepherd::AggregateRoot::BadChangeError, "Expecting "\
          "`#{attribute_name} to be `#{before.inspect}', not "\
          "`#{current_value.inspect}'"
      end

      aggregate.model.send "#{attribute_name}=", after
    end

    def handle_has_many_association(reflection, changes_to_collection)
      apply_changes_to_has_many_association reflection, changes_to_collection
    end

    def handle_has_one_association(reflection, changes)
      apply_changes_to_associated_model(
        aggregate.model.public_send(reflection.name),
        reflection.foreign_key,
        changes,
      )
    end

  private

    def apply_changes_to_has_many_association(association_reflection, changes_set)
      association = aggregate.model.send(association_reflection.name)

      changes_set.each do |index, changes|
        # FIXME
        association.build until association.size >= (index + 1)
        # /FIXME

        associated_model = association[index]

        if associated_model.nil?
          raise ::ActiveShepherd::AggregateRoot::BadChangeError,
            "Can't find record ##{index}"
        end

        apply_changes_to_associated_model(
          associated_model,
          association_reflection.foreign_key,
          changes,
        )
      end
    end

    def apply_changes_to_associated_model(model, foreign_key, changes)
      ActiveShepherd::Aggregate.new(model, foreign_key).changes = changes
    end

    def handle_create_or_destroy_keys
      aggregate.model.mark_for_destruction if destroy?
    end
  end

  class QueryChanges < ActiveShepherd::QueryMethod
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

  class QueryState < ActiveShepherd::QueryMethod
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
        get_state_from_associated_model associated_model, reflection.foreign_key
      end
      query[reflection.name] = collection_state unless collection_state.blank?
    end

    def handle_has_one_association(reflection)
      associated_model = aggregate.model.send reflection.name
      if associated_model
        state = get_state_from_associated_model(
          associated_model,
          reflection.foreign_key,
        )
        query[reflection.name] = state unless state.blank?
      end
    end

  private

    def get_state_from_associated_model(model, foreign_key)
      ActiveShepherd::Aggregate.new(model, foreign_key).state
    end
  end

  class ApplyState < ActiveShepherd::ApplyMethod
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
        apply_state_to_associated_model(
          association.build,
          reflection.foreign_key,
          state,
        )
      end
    end

    def handle_has_one_association(reflection, state)
      associated_model = aggregate.model.send "build_#{reflection.name}"
      apply_state_to_associated_model(
        associated_model,
        reflection.foreign_key,
        state,
      )
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
end
