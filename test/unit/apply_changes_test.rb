require 'test_helper'

class ApplyChangesTest < MiniTest::Unit::TestCase
  def setup
    @aggregate = OpenStruct.new(
      raw_attributes: {},
      traversable_associations: {},
      untraversable_association_names: [],
    )
  end

  def test_raises_aggregate_mismatch_error_if_attributes_are_invalid
    assert_raises(ActiveShepherd::AggregateMismatchError) do
      ActiveShepherd::Methods::ApplyChanges.new(@aggregate, { foo: 'bar' })
    end
  end
end
