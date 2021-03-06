module ActiveShepherd
  class Method
    attr_reader :associations, :attributes

    def self.inherited(base)
      # If you're looking for magic, you've come to the right place
      return unless base.name.match /Methods::/
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

    def recurse(model, foreign_key)
      Aggregate.new model, foreign_key
    end

    def traverse!
      Traversal.new(
        self,
        attributes: attributes,
        associations: associations,
      ).traverse
    end
  end

  class QueryMethod < ActiveShepherd::Method
    attr_reader :query

    def initialize(*args)
      super
      @query = {}
    end

    def setup
      @associations = aggregate.traversable_associations
    end
  end

  class ApplyMethod < ActiveShepherd::Method
    attr_reader :meta_action

    def create?
      meta_action == :_create
    end

    def destroy?
      meta_action == :_destroy
    end

    def setup(hash)
      hash.each do |key, value|
        traversable_association = aggregate.traversable_associations[key]
        if traversable_association.present?
          associations[key] = [traversable_association, value]
        elsif aggregate.untraversable_association_names.include? key
        elsif [:_create, :_destroy].include? key
          @meta_action = key
        elsif aggregate.raw_attributes.keys.include? key.to_s
          attributes[key] = value
        else
          raise ActiveShepherd::AggregateMismatchError, "Attribute `#{key}' "\
            "invalid for `#{aggregate.model.class.name}'"
        end
      end
    end
  end

  # Set up namespace for the method classes
  Methods = Module.new
end
