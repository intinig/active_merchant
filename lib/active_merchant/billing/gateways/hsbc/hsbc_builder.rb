class HsbcBuilder < Builder::XmlMarkup
  # Create XML markup based on the name of the method.  This method
  # is never invoked directly, but is called for each markup method
  # in the markup block.
  def method_missing(sym, *args, &block)
    text = nil
    attrs = nil
    sym = "#{sym}:#{args.shift}" if args.first.kind_of?(Symbol)
    
    args.each do |arg|
      case arg
      when Hash
        attrs ||= {}
        attrs.merge!(arg)
      else
        text ||= ''
        text << arg.to_s
      end
    end
    
    unless args.empty?
      attrs ||= {}
      attrs["DataType"] = "String" unless attrs.has_key?("DataType")
    end
    
    if block
      unless text.nil?
        raise ArgumentError, "XmlMarkup cannot mix a text argument with a block"
      end
      _indent
      _start_tag(sym, attrs)
      _newline
      _nested_structures(block)
      _indent
      _end_tag(sym)
      _newline
    elsif text.nil?
      _indent
      _start_tag(sym, attrs, true)
      _newline
    else
      _indent
      _start_tag(sym, attrs)
      text! text
      _end_tag(sym)
      _newline
    end
    @target
  end
end