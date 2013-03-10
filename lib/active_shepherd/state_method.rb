class ActiveShepherd::StateMethod
  def self.inherited(base)
    # If you're looking for magic, you've come to the right place
    apply_or_query, state_or_changes = base.name.demodulize.underscore.split('_', 2)
    method_name = "#{apply_or_query}_#{state_or_changes}"
    action_proc = ->(*args) { new(*args).send(method_name) }
    base.singleton_class.send(:define_method, method_name, &action_proc)
  end

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

  def create?
    split_hash[:meta_action] == :_create
  end

  def destroy?
    split_hash[:meta_action] == :_destroy
  end

  def split_hash
    @split_hash ||= begin
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
end

