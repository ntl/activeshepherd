class ActiveShepherd::Method
  def self.inherited(base)
    # If you're looking for magic, you've come to the right place
    apply_or_query, state_or_changes = base.name.demodulize.underscore.split('_', 2)
    method_name = "#{apply_or_query}_#{state_or_changes}"
    action_proc = ->(*args) { new(*args).send(method_name) }
    base.singleton_class.send(:define_method, method_name, &action_proc)
  end

  attr_reader :aggregate

  def initialize(aggregate)
    @aggregate = aggregate
  end
end

class ActiveShepherd::QueryMethod < ActiveShepherd::Method ; end

