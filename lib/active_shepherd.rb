module ActiveShepherd ; end

require 'active_shepherd/active_record_shim.rb'
require 'active_shepherd/aggregate'
require 'active_shepherd/aggregate_root'
require 'active_shepherd/apply_changes'
require 'active_shepherd/apply_state'
require 'active_shepherd/changes'
require 'active_shepherd/deep_reverse_changes'
require 'active_shepherd/state'
require 'active_shepherd/version'

module ActiveShepherd
  def self.deep_reverse_changes(changes)
    DeepReverseChanges.new(changes).reverse
  end
end
