class ActiveShepherd::State
  attr_reader :aggregate, :hash

  def initialize(aggregate)
    @aggregate = aggregate
    @hash = {}
  end

  def state
    default_attributes = aggregate.model.class.new.attributes

    {}.tap do |hash|
      aggregate.model.attributes_before_type_cast.each do |attribute_name, value|
        next if aggregate.excluded_attributes.include?(attribute_name)

        value = aggregate.serialize_value(attribute_name, value)

        unless value == default_attributes[attribute_name]
          hash[attribute_name.to_sym] = value
        end
      end

      aggregate.traversable_associations.each do |name, association_reflection|
        serialized = get_via_association(association_reflection)
        hash[name.to_sym] = serialized unless serialized.blank?
      end
    end
  end

private

  def get_via_association(association_reflection)
    foreign_key_to_self = association_reflection.foreign_key
    model_or_collection_of_models = aggregate.model.send(association_reflection.name)

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
end
