require File.dirname(__FILE__) + '/../../test_helper'

class HsbcSupportTest < Test::Unit::TestCase
  def setup
    @request = ""
    @xml = HsbcBuilder.new(:target => @request)
  end
  def test_new_builder_should_append_data_type
    @xml.DocVersion("1.0")
    assert_equal '<DocVersion DataType="String">1.0</DocVersion>', @request
  end

  def test_new_builder_should_not_override_datatype
    @xml.DocVersion("1.0", "DataType" => "S32")
    assert_equal '<DocVersion DataType="S32">1.0</DocVersion>', @request
  end
  
  def test_new_builder_should_not_append_datatype_to_containers
    @xml.DocVersion do
      @xml.Ciao
    end
    assert_equal '<DocVersion><Ciao/></DocVersion>', @request
  end
end


