class Aggro::Aggregate
  EXCLUDED_ATTRIBUTES = ["id"]

  attr_reader :model

  def initialize(model)
    @model = model
  end

  def changes
    {}.tap do |hash|
      @model.changes.each { |k,v| hash[k.to_sym] = v }

      each_traversable_association do |name, macro|
        if macro == :has_many
          records = model.send(name).each
          record_changes = records.with_object({}).with_index do |(associated_model, list), index|
            changes = ::Aggro::Aggregate.new(associated_model).changes
            unless changes.empty?
              list[index] = changes
            end
            list
          end
          unless record_changes.empty?
            hash[name] = record_changes
          end
        else
          associated_model = model.send(name)
          if associated_model
            changes = ::Aggro::Aggregate.new(associated_model).changes
            unless changes.empty?
              hash[name] = changes
            end
          end
        end
      end
    end
  end

  def get_via_association(association_reflection)
    model_or_collection_of_models = model.send(association_reflection.name)

    if model_or_collection_of_models.nil?
      # noop
    elsif association_reflection.macro == :belongs_to
      # noop
    elsif association_reflection.macro == :has_many
      model_or_collection_of_models.to_a.select(&:present?).map do |associated_model|
        ::Aggro::Aggregate.new(associated_model).state
      end
    else
      ::Aggro::Aggregate.new(model_or_collection_of_models).state
    end
  end

  def set_via_association(association_reflection, value)
    if association_reflection.macro == :has_many
      association = model.send(association_reflection.name)

      value.each do |hash|
        associated_model = association.build

        ::Aggro::Aggregate.new(associated_model).state = hash
      end
    elsif association_reflection.macro == :has_one
      associated_model = model.send("build_#{association_reflection.name}")

      ::Aggro::Aggregate.new(associated_model).state = value
    end
  end

  def state
    HashWithIndifferentAccess.new.tap do |hash|
      model.attributes.each do |attribute_name, value|
        next if EXCLUDED_ATTRIBUTES.include?(attribute_name)

        # FIXME: Is this nil check reasonable behavior?
        if value.present?
          hash[attribute_name.to_sym] = value
        end
      end

      model.class.reflect_on_all_associations.each do |association|
        next unless traverse_association?(association)

        serialized = get_via_association(association)
        hash[association.name.to_sym] = serialized unless serialized.blank?
      end
    end
  end

  def state=(hash)
    hash.each do |attribute_or_association_name, value|
      association = model.class.reflect_on_association(attribute_or_association_name.to_sym)

      if association.present?
        if traverse_association?(association)
          set_via_association(association, value)
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

      yield(association.name.to_sym, association.macro)
    end
  end

  def traverse_association?(association)
    return false if association.options[:readonly]
    return false if association.macro == :belongs_to

    true
  end

end
