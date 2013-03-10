class ActiveShepherd::Traversal
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

