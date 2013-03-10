class ActiveShepherd::Changes
  attr_reader :aggregate, :hash

  def initialize(aggregate)
    @aggregate = aggregate
    @hash      = {}
  end

  def build_changes
    set_create_or_destroy_keys

    aggregate.model.changes.each do |k,v|
      v_or_attribute = aggregate.model.attributes_before_type_cast[k]
      v.map! do |possible_serialized_value|
        aggregate.serialize_value(k, possible_serialized_value)
      end

      hash[k.to_sym] = v unless aggregate.excluded_attributes.include?(k.to_s)
    end

    aggregate.traverse_each_association do |name, macro, association_reflection|
      foreign_key_to_self = association_reflection.foreign_key

      if macro == :has_many
        records = aggregate.model.send(name).each
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
        associated_model = aggregate.model.send(name)
        if associated_model
          changes = ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).changes
          unless changes.empty?
            hash[name] = changes
          end
        end
      end
    end
  end

  def changes
    hash
  end

  def self.changes(aggregate)
    new(aggregate).tap(&:build_changes).changes
  end

private

  def set_create_or_destroy_keys
    if not aggregate.model.persisted?
      hash[:_create] = '1'
    elsif aggregate.model.marked_for_destruction?
      hash[:_destroy] = '1'
    end
  end
end
