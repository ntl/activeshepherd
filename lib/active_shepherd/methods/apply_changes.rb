class ActiveShepherd::Methods::ApplyChanges < ActiveShepherd::ApplyMethod
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
    self.class.apply_changes recurse(associated_model, reflection.foreign_key),
      changes
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
      self.class.apply_changes recurse(associated_model, reflection.foreign_key),
        changes
    end
  end
end

