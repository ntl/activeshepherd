class ActiveShepherd::ChangesValidator
  attr_reader :errors, :record

  def initialize(record)
    @record = record
  end

  def validate(changes)
    @errors = []
  end
end
