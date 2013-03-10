class ActiveShepherd::ApplyChanges < ActiveShepherd::StateMethod
  def apply_changes
    handle_create_or_destroy_keys
    apply_changes_to_root_model
    apply_changes_to_associations
  end

private

  def apply_changes_to_root_model
    attributes.each do |attribute_name, (before, after)|
      apply_changes_to_attribute attribute_name, before, after
    end
  end

  def apply_changes_to_associations
    associations.each do |association_name, (association_reflection, changes_or_changes_set)|
      apply_changes_to_association association_reflection, changes_or_changes_set
    end
  end

  def apply_changes_to_association(association_reflection, changes_or_changes_set)
    foreign_key_to_self = association_reflection.foreign_key

    send "apply_changes_to_#{association_reflection.macro}_association",
      association_reflection, foreign_key_to_self, changes_or_changes_set
  end

  def apply_changes_to_has_many_association(association_reflection, foreign_key, changes_set)
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

      apply_changes_to_associated_model associated_model, foreign_key, changes
    end
  end

  def apply_changes_to_has_one_association(association_reflection, foreign_key, changes)
    associated_model = aggregate.model.send(association_reflection.name)
    apply_changes_to_associated_model associated_model, foreign_key, changes
  end

  def apply_changes_to_associated_model(model, foreign_key, changes)
    ActiveShepherd::Aggregate.new(model, foreign_key).changes = changes
  end

  def apply_changes_to_attribute(attribute_name, before, after)
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

  def handle_create_or_destroy_keys
    aggregate.model.mark_for_destruction if destroy?
  end
end
