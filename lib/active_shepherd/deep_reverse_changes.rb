class ActiveShepherd::DeepReverseChanges < Struct.new(:changes)
  def reverse
    changer = ->(h) {
      unless h.is_a?(Hash)
        binding.pry
      end
      h.each_with_object({}) do |(k,v), new_hash|
        if v.is_a?(Array) && v.size == 2
          new_hash[k] = [v.last, v.first]
        elsif v.is_a?(Hash)
          new_hash[k] = changer.call(v)
        elsif :_create == k.to_sym
          new_hash[:_destroy] = v
        elsif :_destroy == k.to_sym
          new_hash[:_create] = v
        end
      end
    }

    changer.call(changes)
  end
end
