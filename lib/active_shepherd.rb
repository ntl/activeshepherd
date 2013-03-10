module ActiveShepherd ; end

require 'active_shepherd/active_record_shim'
require 'active_shepherd/aggregate'
require 'active_shepherd/aggregate_root'
require 'active_shepherd/method'
  require 'active_shepherd/apply_method'
    require 'active_shepherd/methods/apply_changes'
    require 'active_shepherd/methods/apply_state'
    require 'active_shepherd/methods/query_changes'
    require 'active_shepherd/methods/query_state'
require 'active_shepherd/deep_reverse_changes'
require 'active_shepherd/version'

module ActiveShepherd
  def self.deep_reverse_changes(changes)
    DeepReverseChanges.new(changes).reverse
  end
end
