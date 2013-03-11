class ActiveShepherd::ClassValidator
  attr_reader :errors, :klass

  def initialize(klass)
    @klass = klass
    @erros = []
  end

  def validate
  end
end
