class ActiveShepherd::Methods
  class ApplyChanges < ActiveShepherd::ApplyMethod
    def apply_changes
      aggregate.model.mark_for_destruction if destroy?
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

    def handle_has_many_association(reflection, collection_changes)
      apply_changes_to_has_many_association reflection, collection_changes
    end

    def handle_has_one_association(reflection, changes)
      associated_model = aggregate.model.public_send reflection.name
      recurse(associated_model, reflection.foreign_key).changes = changes
    end

  private

    def apply_changes_to_has_many_association(reflection, collection_changes)
      association = aggregate.model.send reflection.name

      collection_changes.each do |index, changes|
        # FIXME
        association.build until association.size >= (index + 1)
        # /FIXME

        associated_model = association[index]
        if associated_model.nil?
          raise ::ActiveShepherd::AggregateRoot::BadChangeError,
            "Can't find record ##{index}"
        end
        recurse(associated_model, reflection.foreign_key).changes = changes
      end
    end
  end

  class QueryChanges < ActiveShepherd::QueryMethod
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
        associated_model = association.build
        recurse(associated_model, reflection.foreign_key).state = state
      end
    end

    def handle_has_one_association(reflection, state)
      associated_model = aggregate.model.send "build_#{reflection.name}"
      recurse(associated_model, reflection.foreign_key).state = state
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
end
