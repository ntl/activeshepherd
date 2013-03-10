class ActiveShepherd::Changes
  attr_reader :aggregate, :hash

  def initialize(aggregate)
    @aggregate = aggregate
    @hash      = {}
  end

  def build_changes
    set_create_or_destroy_keys

    add_changes_on_root_model

    aggregate.traversable_associations.values.each do |association_reflection|
      add_changes_on_association association_reflection
    end
  end

  def changes
    hash
  end

  def self.changes(aggregate)
    new(aggregate).tap(&:build_changes).changes
  end

private

  def add_changes_on_association(association_reflection)
    foreign_key_to_self = association_reflection.foreign_key
    send "add_changes_on_#{association_reflection.macro}_association",
      association_reflection.name, foreign_key_to_self
  end

  def add_changes_on_has_many_association(name, foreign_key)
    records = aggregate.model.send(name).each
    record_changes = records.with_object({}).with_index do |(associated_model, list), index|
      changes = changes_for_associated_model associated_model, foreign_key
      list[index] = changes unless changes.empty?
    end
    hash[name] = record_changes unless record_changes.empty?
  end

  def add_changes_on_has_one_association(name, foreign_key)
    associated_model = aggregate.model.send(name)
    return unless associated_model.present?

    changes = changes_for_associated_model associated_model, foreign_key
    hash[name] = changes unless changes.empty?
  end

  def add_changes_on_root_model
    aggregate.model.changes.each do |k,v|
      v_or_attribute = aggregate.model.attributes_before_type_cast[k]
      v.map! do |possible_serialized_value|
        aggregate.serialize_value(k, possible_serialized_value)
      end

      hash[k.to_sym] = v unless aggregate.excluded_attributes.include?(k.to_s)
    end
  end

  def changes_for_associated_model(model, foreign_key)
    ActiveShepherd::Aggregate.new(model, foreign_key).changes
  end

  def set_create_or_destroy_keys
    if not aggregate.model.persisted?
      hash[:_create] = '1'
    elsif aggregate.model.marked_for_destruction?
      hash[:_destroy] = '1'
    end
  end
end
