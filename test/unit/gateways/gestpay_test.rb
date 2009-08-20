require File.dirname(__FILE__) + '/../../test_helper'

class GestpayTest < Test::Unit::TestCase
  
  def setup
    @gateway = GestpayGateway.new(
      :shop_login => 'GESPAY23223',
      :test => true
     )

    # For Gestpay first and last name are mandatory
    @credit_card = credit_card(4567350000427977, :month => 05, :year => 2007, :type => :visa, :first_name => "Ivan Rossano", :last_name => "Vaghi")
    @amount = Money.new(110, 'EUR')
    
    @options = { 
      :shop_transaction_id => 'order_number_2'
    }

  end

  def test_should_require_shop_login
    begin
      g = GestpayGateway.new
    rescue Exception => e
      assert_equal "#<ArgumentError: Missing required parameter: shop_login>", e.inspect
    end
  end
  
  def test_gestpay_url_should_return_correct_url
    g = GestpayGateway.new(
      :shop_login => 'GESPAY23223',
      :test => true
     )
    assert g.send(:gestpay_url).match(/test/)

    g = GestpayGateway.new(
      :shop_login => 'GESPAY23223'
     )
    assert !g.send(:gestpay_url).match(/test/)
  end

  def test_transaction_data_should_correctly_build_query_string
    transaction_data = GestpayGateway::TransactionData.new({:money => @amount, :credit_card => @credit_card}.merge(@options))
    assert_equal correct_transaction_data_query_string, transaction_data.to_str
  end
  
  def test_operation_url_should_correctly_build_query_string
    transaction_data = GestpayGateway::TransactionData.new({:money => @amount, :credit_card => @credit_card}.merge(@options))
    assert_equal correct_operation_url_query_string, @gateway.send(:operation_url, "PAGAMS2S.asp", transaction_data.to_str)
  end
  
  # def test_get_key_from_response_should_fetch_key
  #   r = REXML::Document.new(successful_authorize_response).root.elements
  #   key = @gateway.send(:get_key_from_response, r, "EngineDocList.EngineDoc.OrderFormDoc.Transaction.CardProcResp.ProcReturnMsg")
  #   assert_equal "Approved", key, r.inspect
  # end
  # 
  # def test_get_key_from_response_should_not_freak_out_on_non_existant_key
  #   r = REXML::Document.new(successful_authorize_response).root.elements
  #   key = @gateway.send(:get_key_from_response, r, "FooBar.Asd")
  #   assert_nil key
  # end
  # 
  # def test_get_message_from_response_should_return_one_message
  #   r = REXML::Document.new(insufficient_permission_response).root.elements
  #   message = @gateway.send(:get_message_from_response, r)
  #   assert_equal "Insufficient permissions to perform requested operation.", message
  # end
  # 
  # def test_get_message_from_response_should_return_multiple_messages
  #   r = REXML::Document.new(forged_multi_message_response).root.elements
  #   message = @gateway.send(:get_message_from_response, r)
  #   assert_equal "Insufficient permissions to perform requested operation., Insufficient permissions to perform requested operation.", message
  # end
  # 
  # def test_should_build_successful_authorize_request
  #   assert_successful_build("authorize", @amount, @credit_card, @options)
  # end
  # 
  # def test_should_build_successful_authorize_request_with_payer_authentication
  #   request = @gateway.send(:build_authorize_request, @amount, @credit_card, @options.merge({:payer_authentication_code => 'ciao'}))
  #   assert request.match(/PayerAuthenticationCode/)
  # end
  # 
  # def test_successful_authorize
  #   assert_successful_request("authorize", @amount, @credit_card, @options)
  # end
  #   
  # def test_failed_authorize
  #   @gateway.expects(:ssl_post).returns(wrong_total_authorize_response)
  #   
  #   assert response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_failure response
  # 
  #   assert response.test?
  # end
  # 
  # def test_should_build_successful_capture_request
  #   assert_successful_build("capture", @options)
  # end
  # 
  # def test_successful_capture
  #   assert_successful_request("capture", @amount, nil, @options)
  # end
  # 
  # def test_should_build_successful_void_request
  #   assert_successful_build("void", @options)
  # end
  # 
  # def test_successful_void
  #   assert_successful_request("void", @amount, nil, @options)
  # end
  # 
  # def test_should_build_successful_refund_request
  #   assert_successful_build("refund", @amount, @credit_card, @options)
  # end
  # 
  # def test_successful_refund
  #   assert_successful_request("refund", @amount, @credit_card, @options)
  # end
  
  protected
  
  def correct_transaction_data_query_string
    "PAY1_SHOPTRANSACTIONID=#{@options[:shop_transaction_id]}*P1*PAY1_CVV=#{@credit_card.verification_value}*P1*PAY1_UICCODE=242*P1*PAY1_CHNAME=Ivan+Rossano+Vaghi*P1*PAY1_EXPMONTH=05*P1*PAY1_AMOUNT=1.1*P1*PAY1_EXPYEAR=07*P1*PAY1_CARDNUMBER=#{@credit_card.number}"
  end   
  
  def correct_operation_url_query_string
    "https://testecomm.sella.it/Gestpay/PAGAMS2S.asp?a=GESPAY23223&b=PAY1_SHOPTRANSACTIONID=order_number_2*P1*PAY1_CVV=123*P1*PAY1_UICCODE=242*P1*PAY1_CHNAME=Ivan+Rossano+Vaghi*P1*PAY1_EXPMONTH=05*P1*PAY1_AMOUNT=1.1*P1*PAY1_EXPYEAR=07*P1*PAY1_CARDNUMBER=4567350000427977&c=S3.1.0"
  end    

  # def prepare_for_comparison(string)
  #   string.gsub(/\s{2,}/, ' ').gsub(/(\/?)> </, "#{$1}><")
  # end
  # 
  # def assert_equal_xml(expected, actual)
  #   assert_equal prepare_for_comparison(REXML::Document.new(expected).root.to_s), prepare_for_comparison(REXML::Document.new(actual).root.to_s)
  # end
  #  
  # def assert_successful_build(operation, *options)
  #   request = @gateway.send("build_#{operation}_request", *options)
  #   assert_equal_xml send("successful_#{operation}_request"), request
  # end
  # 
  # def assert_successful_request(operation, *options)
  #   @gateway.expects(:ssl_post).returns(send("successful_#{operation}_response"))
  #   
  #   assert response = @gateway.send(operation, *options)
  #   assert_success response
  #   
  #   assert response.test?
  # end
end
