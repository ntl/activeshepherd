class ActiveShepherd::ApplyMethod < ActiveShepherd::Method
  attr_reader :split_hash

  def initialize(aggregate, hash)
    super aggregate
    @split_hash = build_split_hash(hash)
  end

private

  def associations
    split_hash[:associations]
  end

  def attributes
    split_hash[:attributes]
  end

  def create?
    split_hash[:meta_action] == :_create
  end

  def destroy?
    split_hash[:meta_action] == :_destroy
  end

  def build_split_hash(hash)
    split_hash = { associations: {}, attributes: {} }
    hash.each_with_object(split_hash) do |(key, value), by_key|
      traversable_association = aggregate.traversable_associations[key]
      if traversable_association.present?
        by_key[:associations][key] = [traversable_association, value]
      elsif aggregate.untraversable_association_names.include? key
      elsif [:_create, :_destroy].include? key.to_sym
        by_key[:meta_action] = key.to_sym
      else
        by_key[:attributes][key] = value
      end
    end
  end
end

