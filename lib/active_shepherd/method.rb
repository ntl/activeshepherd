class ActiveShepherd::Method
  attr_reader :associations, :attributes

  def self.inherited(base)
    # If you're looking for magic, you've come to the right place
    return unless base.name.match /^ActiveShepherd::Methods::/
    apply_or_query, state_or_changes = base.name.demodulize.underscore.split('_', 2)
    method_name = "#{apply_or_query}_#{state_or_changes}"
    action_proc = ->(*args) { new(*args).send(method_name) }
    base.singleton_class.send :define_method, method_name, &action_proc
  end

  attr_reader :aggregate

  def initialize(*args)
    @aggregate    = args.shift
    @associations = {}
    @attributes   = {}

    setup *args
  end

  def traverse!
    ActiveShepherd::Traversal.new(
      self,
      attributes: attributes,
      associations: associations,
    ).traverse
  end
end

module ActiveShepherd
  class Traversal
    attr_reader :attributes, :associations, :visitor

    def initialize(visitor, params = {})
      @associations = params[:associations]
      @attributes   = params[:attributes]
      @visitor      = visitor
    end

    def traverse
      attributes.each do |attribute_name, object|
        visit :handle_attribute, attribute_name, object
      end

      # XXX: no need for name here
      associations.each do |name, (reflection, object)|
        if reflection.macro == :has_many
          visit :handle_has_many_association, reflection, object
        elsif reflection.macro == :has_one
          visit :handle_has_one_association, reflection, object
        end
      end
    end

    def visit(method_name, arg1, arg2)
      if visitor.respond_to? method_name
        if visitor.method(method_name).arity == 2
          visitor.public_send method_name, arg1, arg2
        else
          visitor.public_send method_name, arg1, *Array.wrap(arg2)
        end
      end
    end
  end
end

class ActiveShepherd::QueryMethod < ActiveShepherd::Method
  attr_reader :query

  def initialize(*args)
    super
    @query = {}
  end

private

  def setup
    @associations = aggregate.traversable_associations
  end
end

class ActiveShepherd::ApplyMethod < ActiveShepherd::Method
  attr_reader :meta_action

  def create?
    meta_action == :_create
  end

  def destroy?
    meta_action == :_destroy
  end

private

  def setup(hash)
    hash.each do |key, value|
      traversable_association = aggregate.traversable_associations[key]
      if traversable_association.present?
        associations[key] = [traversable_association, value]
      elsif aggregate.untraversable_association_names.include? key
      elsif [:_create, :_destroy].include? key.to_sym
        @meta_action = key.to_sym
      else
        attributes[key] = value
      end
    end
  end
end
