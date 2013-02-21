class ActiveShepherd::Aggregate
  attr_reader :excluded_attributes
  attr_reader :model

  def initialize(model, excluded_attributes = [])
    @model = model

    @excluded_attributes = ["id", "created_at", "updated_at"]
    @excluded_attributes.concat(Array.wrap(excluded_attributes).map(&:to_s))
  end

  def changes
    {}.tap do |hash|
      @model.changes.each do |k,v|
        hash[k.to_sym] = v unless excluded_attributes.include?(k.to_s)
      end

      each_traversable_association do |name, macro, association_reflection|
        foreign_key_to_self = association_reflection.foreign_key

        if macro == :has_many
          records = model.send(name).each
          record_changes = records.with_object({}).with_index do |(associated_model, list), index|
            changes = ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).changes
            unless changes.empty?
              list[index] = changes
            end
            list
          end
          unless record_changes.empty?
            hash[name] = record_changes
          end
        elsif macro == :has_one
          associated_model = model.send(name)
          if associated_model
            changes = ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).changes
            unless changes.empty?
              hash[name] = changes
            end
          end
        end
      end
    end
  end

  def changes=(hash)
    hash.each do |attribute_or_association_name, (before, after)|
      association_reflection = model.class.reflect_on_association(attribute_or_association_name.to_sym)

      if association_reflection.present?
        if traverse_association?(association_reflection)
          unless after.nil?
            raise ::ActiveShepherd::AggregateRoot::BadChangeError
          end

          foreign_key_to_self = association_reflection.foreign_key

          if association_reflection.macro == :has_many
            association = model.send(association_reflection.name)

            before.each do |index, changes_for_associated_model|
              # FIXME
              until association.size >= (index + 1)
                association.build
              end
              # /FIXME

              associated_model = association[index]

              if associated_model.nil?
                raise ::ActiveShepherd::AggregateRoot::BadChangeError, "Can't find record ##{index}"
              end

              ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).changes = changes_for_associated_model
            end
            
          elsif association_reflection.macro == :has_one
            associated_model = model.send(association_reflection.name)
            changes_for_associated_model = before
            ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).changes = changes_for_associated_model
          end
        end
      else
        getter = "#{attribute_or_association_name}"
        setter = "#{attribute_or_association_name}="

        current_value = model.send(getter)

        unless current_value == before
          raise ::ActiveShepherd::BadChangeError, "Expecting "
            "`#{attribute_or_association_name} to be `#{before.inspect}', not "\
            "`#{current_value.inspect}'"
        end

        model.send(setter, after)
      end
    end
  end

  def get_via_association(association_reflection)
    foreign_key_to_self = association_reflection.foreign_key
    model_or_collection_of_models = model.send(association_reflection.name)

    if model_or_collection_of_models.nil?
      # noop
    elsif association_reflection.macro == :belongs_to
      # noop
    elsif association_reflection.macro == :has_many
      model_or_collection_of_models.to_a.select(&:present?).map do |associated_model|
        ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).state
      end
    else
      ::ActiveShepherd::Aggregate.new(model_or_collection_of_models, foreign_key_to_self).state
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

  def state
    default_attributes = model.class.new.attributes

    {}.tap do |hash|
      model.attributes.each do |attribute_name, value|
        next if excluded_attributes.include?(attribute_name)

        unless value == default_attributes[attribute_name]
          hash[attribute_name.to_sym] = value
        end
      end

      each_traversable_association do |name, macro, association_reflection|
        serialized = get_via_association(association_reflection)
        hash[name.to_sym] = serialized unless serialized.blank?
      end
    end
  end

  def state=(hash)
    mark_all_associated_objects_for_destruction

    default_attributes = model.class.new.attributes
    ignored_attribute_names = hash.keys.map(&:to_s) + excluded_attributes

    (default_attributes.keys - ignored_attribute_names).each do |attribute_name|
      current_value = model.attributes[attribute_name]
      default_value = default_attributes[attribute_name]

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
        setter = "#{attribute_or_association_name}="
        model.send(setter, value)
      end
    end
  end

private

  def each_traversable_association
    model.class.reflect_on_all_associations.select do |association|
      next unless traverse_association?(association)

      yield(association.name.to_sym, association.macro, association)
    end
  end

  def traverse_association?(association)
    return false if association.options[:readonly]
    return false if association.macro == :belongs_to

    true
  end

  def mark_all_associated_objects_for_destruction
    each_traversable_association do |name, macro, reflection|
      if macro == :has_many
        model.send(name).each { |record| record.mark_for_destruction }
      elsif macro == :has_one
        model.send(name).try(&:mark_for_destruction)
      end
    end
  end

end