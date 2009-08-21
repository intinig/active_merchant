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
    
  protected
  
  def correct_transaction_data_query_string
    "PAY1_SHOPTRANSACTIONID=#{@options[:shop_transaction_id]}*P1*PAY1_CVV=#{@credit_card.verification_value}*P1*PAY1_UICCODE=242*P1*PAY1_CHNAME=Ivan+Rossano+Vaghi*P1*PAY1_EXPMONTH=05*P1*PAY1_AMOUNT=1.1*P1*PAY1_EXPYEAR=07*P1*PAY1_CARDNUMBER=#{@credit_card.number}"
  end   
  
  def correct_operation_url_query_string
    "https://testecomm.sella.it/Gestpay/PAGAMS2S.asp?a=GESPAY23223&b=PAY1_SHOPTRANSACTIONID=order_number_2*P1*PAY1_CVV=123*P1*PAY1_UICCODE=242*P1*PAY1_CHNAME=Ivan+Rossano+Vaghi*P1*PAY1_EXPMONTH=05*P1*PAY1_AMOUNT=1.1*P1*PAY1_EXPYEAR=07*P1*PAY1_CARDNUMBER=4567350000427977&c=S3.1.0"
  end    

end
