module ActiveShepherd
  def self.enable!(activerecord_base)
    class << activerecord_base
      # FIXME: make this actually check the model to meet the criteria for being
      # an Aggregate Root
      def able_to_act_as_aggregate_root?
        true
      end

      def act_as_aggregate_root!
        include ::ActiveShepherd::AggregateRoot
      end
    end
  end
end
