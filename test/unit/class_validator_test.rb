require 'test_helper'

class ClassValidatorTest < MiniTest::Unit::TestCase
  def test_model_must_autosave_associations
    skip
  end

  def test_model_must_validate_associations
    skip
  end

  def test_model_must_destroy_associations
    skip
  end

  def test_all_traversable_associations_have_inverse_of_setup
    skip
  end

  def test_must_prohibit_references_to_associations
    skip
  end

  def test_associated_objects_must_touch_root
    skip
  end

  # class PingPong
  #   has_many :foo_bar, dependent: :destroy # Foo::Bar not valid aggregate without this
  # end
  #
  # class Foo::Bar
  #   belongs_to :ping_pong
  # end
  def test_references_in_associations_to_objects_outside_aggregate_must_destroy_or_nullify_reference
    skip
  end

  # class Foo
  #   has_many :baz, through: :bar
  #   has_many :bar
  # end
  #
  # class Bar
  #   has_many :baz
  #   belongs_to :foo
  # end
  #
  # class Baz
  #   belongs_to :bar
  # end
  #
  # "If Foo has_many Bar is valid, and Bar has_many Baz is valid, then I'm not
  # worried about Foo has_many Baz :through Bar"
  def test_has_many_through_only_invalid_if_associations_not_part_of_aggregate
    skip
  end
end
