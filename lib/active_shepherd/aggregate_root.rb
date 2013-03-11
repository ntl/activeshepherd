module ActiveShepherd::AggregateRoot
  AggregateMismatchError = Class.new(StandardError)
  BadChangeError         = Class.new(StandardError)
  InvalidChangesError    = Class.new(StandardError)

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Private: returns the behind the scenes object that does all the work
  def aggro
    @aggro ||= ::ActiveShepherd::Aggregate.new(self)
  end
  private :aggro
  
  # Public: Given a serializable blob of changes (Hash, Array, and String)
  # objects, apply those changes to 
  #
  # Examples:
  # 
  #   @project.aggregate_changes = { name: ["Clean House", "Clean My House"] }
  #
  # Returns nothing.
  # Raises ActiveShepherd::BadChangeError if a particular attribute change is 
  #   not a two element array.
  # Raises ActiveShepherd::InvalidChangesError if the changes supplied do not
  #   pass #valid_aggregate_changes? (see below)
  # Raises an ActiveShepherd::AggregateMismatchError if any objects in the
  #   aggregate are being asked to change attributes that do not exist.
  def aggregate_changes=(changes)
    ActiveShepherd::Methods::ApplyChanges.apply_changes aggro, changes
  end

  # Public: Reverses the effect of #aggregate_changes=
  def reverse_aggregate_changes=(changes)
    self.aggregate_changes = ::ActiveShepherd::DeepReverseChanges.new(changes).reverse
  end

  # Public: Returns the list of changes to the aggregate that would persist if
  # #save were called on the aggregate root.
  #
  # Examples
  #
  #   @project.aggregate_changes
  #   # => { name: ["Clean House", "Clean My House"], todos: [{ text: ["Take out trash", "Take out the trash" ...
  #
  # Returns all changes in the aggregate
  def aggregate_changes
    ActiveShepherd::Methods::QueryChanges.query_changes aggro
  end

  # Public: Injects the entire state of the aggregate from a serializable blob.
  #
  # Examples:
  # 
  #   @project.aggregate_state = { name: "Clean House", todos: [{ text: "Take out trash" ...
  #
  # Returns nothing.
  # Raises an AggregateMismatchError if the blob contains references to objects
  #   or attributes that do not exist in this aggregate.
  def aggregate_state=(blob)
    ActiveShepherd::Methods::ApplyState.apply_state aggro, blob
  end

  # Public: Returns the entire state of the aggregate as a serializable blob.
  # All id values (primary keys) are extracted.
  #
  # Examples
  # 
  #   @project.aggregate_state
  #   # => { name: "Clean House", todos: [{ text: "Take out trash" ...
  #
  # Returns serializable blob.
  def aggregate_state
    ActiveShepherd::Methods::QueryState.query_state aggro
  end

  # Public: Validates a set of changes for the aggregate root.
  #
  #  * If the changes were applied, would the aggregate be valid?
  #  * Does deep_reverse(deep_reverse(changes)) == changes?
  #  * If I apply the changes, and then apply deep_reverse(changes), does
  #    #aggregate_state change?
  #
  # See ActiveShepherd.deep_reverse
  #
  # Examples:
  # 
  #   @project.valid_aggregate_changes?(@project.aggregate_changes)
  #   # => true
  #
  # Returns true if and only if the supplied changes pass muster.
  def valid_aggregate_changes?(changes)
    aggro.valid_changes?(changes)
  end

  module ClassMethods
    # Public: Determines whether or not the including class can behave like an
    # aggregate. Designed to be used by tests that want to make sure that any
    # of the models that make up the aggregate never change in a way that would
    # break the functionality of Aggregate::Root.
    #
    # In order for this method to return true, this model and its associated 
    # models are each checked rigorously to ensure they are wired up in a way
    # that meets the requirements of an aggregate root. These requirements are:
    #
    #  * The root model is valid if and only if itself and all associated models
    #    under its' namespace are valid. (:validate is true on the association)
    #  * When any root model is destroyed, all associated models in the
    #    aggregate boundary are also destroyed. (:dependent => :destroy)
    #  * The entire object constellation within the boundary can be traversed
    #    without accessing the persistence layer, providing they have all been
    #    eager loaded. (:inverse_of is set on the associations)
    #  * All models under the namespace of the root model are only referenced
    #    inside this aggregate boundary.
    #  * Any references to models outside this aggregate boundary are read-only.
    #
    # Returns true if and only if this model is an aggregate root.
    def behave_like_an_aggregate?
      ::ActiveShepherd::ClassValidator.new(self).valid?
    end
  end
end
