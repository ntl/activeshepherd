module ActiveShepherd::AggregateRoot
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Private: returns the behind the scenes object that does all the work
  def aggregate
    @aggregate ||= ActiveShepherd::Aggregate.new(self)
  end
  private :aggregate
  
  # Public: Given a serializable blob of changes (Hash, Array, and String)
  # objects, apply those changes to 
  #
  # Examples:
  # 
  #   @project.aggregate_changes = { name: ["Clean House", "Clean My House"] }
  #
  # Returns nothing.
  # Raises ActiveShepherd::InvalidChangesError if the changes supplied do not
  #   pass #valid_aggregate_changes? (see below)
  # Raises ActiveShepherd::BadChangeError if a particular attribute change
  #   cannot be applied.
  # Raises an ActiveShepherd::AggregateMismatchError if any objects in the
  #   aggregate are being asked to change attributes that do not exist.
  def aggregate_changes=(changes)
    changes_errors = valid_aggregate_changes? changes, false
    unless changes_errors.empty?
      raise ActiveShepherd::InvalidChangesError, "changes hash is invalid: "\
        "#{changes_errors.join(', ')}"
    end
    ActiveShepherd::Methods::ApplyChanges.apply_changes aggregate, changes
  end

  # Public: Reverses the effect of #aggregate_changes=
  def reverse_aggregate_changes=(changes)
    self.aggregate_changes = ActiveShepherd::DeepReverseChanges.new(changes).reverse
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
    ActiveShepherd::Methods::QueryChanges.query_changes aggregate
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
    ActiveShepherd::Methods::ApplyState.apply_state aggregate, blob
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
    ActiveShepherd::Methods::QueryState.query_state aggregate
  end

  # Public: Validates a set of changes for the aggregate root.
  #
  #  * Does deep_reverse(deep_reverse(changes)) == changes?
  #  * Assuming the model is currently valid, if the changes were applied,
  #    would the aggregate be valid?
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
  def valid_aggregate_changes?(changes, emit_boolean = true)
    errors = ActiveShepherd::ChangesValidator.new(self).validate changes
    emit_boolean ? errors.blank? : errors
  end

  module ClassMethods
    # Public: Determines whether or not the including class can behave like an
    # aggregate. Designed to be used by tests that want to make sure that any
    # of the models that make up the aggregate never change in a way that would
    # break the functionality of Aggregate::Root.
    #
    # In order for this method to return true, this model and its associated 
    # models are each checked rigorously to ensure they are wired up in a way
    # that meets the requirements of ActiveShepherd. These requirements are:
    #
    #  * The root model autosaves all associated models in the aggregate.
    #    (:autosave is true on the association)
    #  * The root model validates all associated models in the aggregate.
    #    (:validate is true on the association)
    #  * Associated objects touch the root model when they are updated
    #  * When any root model is destroyed, all associated models in the
    #    aggregate boundary are also destroyed, or else their references are
    #    nullified. (:dependent => :destroy/:nullify)
    #  * The entire object constellation within the boundary can be traversed
    #    without accessing the persistence layer, providing they have all been
    #    eager loaded. (:inverse_of is set on the associations)
    #  * All models under the namespace of the root model are only referenced
    #    inside this aggregate boundary.
    #  * Any references to models outside this aggregate boundary are read-only.
    #
    # Returns true if and only if this model is an aggregate root.
    def behave_like_an_aggregate?(emit_boolean = true)
      errors = ActiveShepherd::ClassValidator.new(self).validate
      emit_boolean ? errors.blank? : errors
    end
  end
end
