class ActiveShepherd::ApplyChanges
  attr_reader :aggregate, :hash

  def initialize(aggregate, hash)
    @aggregate = aggregate
    @hash      = hash
  end

  def apply_changes
    hash.each do |attribute_or_association_name, (before, after)|
      association_reflection = aggregate.model.class.reflect_on_association(attribute_or_association_name.to_sym)

      if association_reflection.present?
        if aggregate.traverse_association?(association_reflection)
          unless after.nil?
            raise ::ActiveShepherd::AggregateRoot::BadChangeError
          end

          foreign_key_to_self = association_reflection.foreign_key

          if association_reflection.macro == :has_many
            association = aggregate.model.send(association_reflection.name)

            before.each do |index, changes_for_associated_model|
              # FIXME
              until association.size >= (index + 1)
                association.build
              end
              # /FIXME

              associated_model = association[index]

              if associated_model.nil?
                raise ::ActiveShepherd::AggregateRoot::BadChangeError, "Can't find record ##{index}"
              end

              ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).changes = changes_for_associated_model
            end
            
          elsif association_reflection.macro == :has_one
            associated_model = aggregate.model.send(association_reflection.name)
            changes_for_associated_model = before
            ::ActiveShepherd::Aggregate.new(associated_model, foreign_key_to_self).changes = changes_for_associated_model
          end
        end
      elsif attribute_or_association_name.to_s == "_create"
      elsif attribute_or_association_name.to_s == "_destroy"
        aggregate.model.mark_for_destruction
      else
        attribute_name = attribute_or_association_name
        setter = "#{attribute_or_association_name}="

        current_value = aggregate.model.send(attribute_name)

        before = aggregate.deserialize_value(attribute_name, before)
        after  = aggregate.deserialize_value(attribute_name, after)
 
        unless current_value == before
          raise ::ActiveShepherd::AggregateRoot::BadChangeError, "Expecting "\
            "`#{attribute_or_association_name} to be `#{before.inspect}', not "\
            "`#{current_value.inspect}'"
        end

        aggregate.model.send(setter, after)
      end
    end
  end
end
