class ActiveShepherd::Aggregate
  attr_reader :excluded_attributes
  attr_reader :model

  def initialize(model, excluded_attributes = [])
    @model = model

    @excluded_attributes = ["id", "created_at", "updated_at"]
    @excluded_attributes.concat(Array.wrap(excluded_attributes).map(&:to_s))
  end

  def default_attributes
    model.class.new.attributes
  end

  def changes
    ActiveShepherd::Changes.changes(self)
  end

  def changes=(hash)
    ActiveShepherd::ApplyChanges.apply_changes(self, hash)
  end

  def state
    ActiveShepherd::State.new(self).state
  end

  def traversable_associations
    associations.traversable
  end

  def untraversable_associations
    associations.untraversable
  end

  def serialize_value(attribute_name, value)
    run_through_serializer(attribute_name, value, :dump)
  end

  def deserialize_value(attribute_name, value)
    run_through_serializer(attribute_name, value, :load)
  end

  # XXX[
  def traverse_each_association(&block)
    traversable_associations.each do |name, association|
      yield(name.to_sym, association.macro, association)
    end
  end

  def set_via_association(association_reflection, value)
    foreign_key_to_self = association_reflection.foreign_key

    if association_reflection.macro == :has_many
      association = model.send(association_reflection.name)

      value.each do |hash|
        associated_model = association.build

        ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).state = hash
      end
    elsif association_reflection.macro == :has_one
      associated_model = model.send("build_#{association_reflection.name}")

      ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).state = value
    end
  end

  def state=(hash)
    mark_all_associated_objects_for_destruction

    default_attributes = model.class.new.attributes
    ignored_attribute_names = hash.keys.map(&:to_s) + excluded_attributes

    (default_attributes.keys - ignored_attribute_names).each do |attribute_name|
      current_value = model.attributes[attribute_name]
      default_value = default_attributes[attribute_name]

      unless deserialize_value(attribute_name, default_value) == default_value
        raise 'Have not handled this use case yet; serialized attributes with a default value'
      end

      next if default_value == current_value

      model.send("#{attribute_name}=", default_value)
    end

    hash.each do |attribute_or_association_name, value|
      association_reflection = model.class.reflect_on_association(attribute_or_association_name.to_sym)

      if association_reflection.present?
        if traverse_association?(association_reflection)
          set_via_association(association_reflection, value)
        end
      else
        attribute_name = attribute_or_association_name
        setter = "#{attribute_name}="
        model.send(setter, deserialize_value(attribute_name, value))
      end
    end
  end
  # ]XXX

private

  def associations
    @associations ||= begin
      all_associations = model.class.reflect_on_all_associations
      ostruct = OpenStruct.new untraversable: {}, traversable: {}
      all_associations.each_with_object(ostruct) do |association_reflection, ostruct|
        if traverse_association?(association_reflection)
          key = :traversable
        else
          key = :untraversable
        end
        ostruct.send(key)[association_reflection.name] = association_reflection
      end
    end
  end

  def run_through_serializer(attribute_name, value, method)
    serializer = model.class.serialized_attributes[attribute_name.to_s]
    if serializer
      serializer.send(method, value)
    else
      value
    end
  end

  # XXX[
  def mark_all_associated_objects_for_destruction
    traverse_each_association do |name, macro, reflection|
      if macro == :has_many
        model.send(name).each { |record| record.mark_for_destruction }
      elsif macro == :has_one
        model.send(name).try(&:mark_for_destruction)
      end
    end
  end
  # ]XXX

  def traverse_association?(association)
    return false if association.options[:readonly]
    return false if association.macro == :belongs_to

    true
  end

end
