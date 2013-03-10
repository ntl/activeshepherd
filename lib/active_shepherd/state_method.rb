class ActiveShepherd::StateMethod
  attr_reader :aggregate, :hash

  def initialize(aggregate, hash = {})
    @aggregate = aggregate
    @hash      = hash
  end

private

  def associations
    split_hash[:associations]
  end

  def attributes
    split_hash[:attributes]
  end

  def split_hash
    @split_hash ||= begin
      split_hash = { associations: {}, attributes: {} }
      hash.each_with_object(split_hash) do |(key, value), by_key|
        traversable_association = aggregate.traversable_associations[key]
        if traversable_association.present?
          by_key[:associations][key] = [traversable_association, value]
        elsif aggregate.untraversable_association_names.include? key
        else
          by_key[:attributes][key] = value
        end
      end
    end
  end
end

