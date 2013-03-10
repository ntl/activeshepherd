class ActiveShepherd::QueryState
  attr_reader :aggregate, :hash

  def initialize(aggregate)
    @aggregate = aggregate
    @hash = {}
  end

  def query_state
    add_state_from_root_model

    aggregate.traversable_associations.each do |name, association_reflection|
      add_state_from_association name, association_reflection
    end

    hash
  end

  def self.query_state(aggregate)
    new(aggregate).query_state
  end

private

  def add_state_from_root_model
    aggregate.model.attributes_before_type_cast.each do |attribute_name, value|
      next if aggregate.excluded_attributes.include?(attribute_name)

      value = aggregate.serialize_value(attribute_name, value)

      unless value == aggregate.default_attributes[attribute_name]
        hash[attribute_name.to_sym] = value
      end
    end
  end

  def add_state_from_association(name, association_reflection)
    serialized = association_state(name, association_reflection)
    hash[name.to_sym] = serialized unless serialized.blank?
  end

  def association_state(name, association_reflection)
    foreign_key_to_self = association_reflection.foreign_key

    if association_reflection.macro == :has_one
      associated_model = aggregate.model.send name
      if associated_model
        state_of_associated_model associated_model, foreign_key_to_self
      end
    elsif association_reflection.macro == :has_many
      aggregate.model.send(name).map do |associated_model|
        state_of_associated_model associated_model, foreign_key_to_self
      end
    end
  end

  def state_of_associated_model(model, foreign_key)
    ActiveShepherd::Aggregate.new(model, foreign_key).state
  end
end
