require 'test_helper'

ActiveMerchant::Billing::Base.mode = :test

# ActiveMerchant accepts all amounts as Integer values in cents
# $10.00
amount = '1.00'

credit_card = ActiveMerchant::Billing::CreditCard.new(
                :first_name         => 'Bob',
                :last_name          => 'Bobsen',
                :number             => '4111111111111111',
                :month              => "08",
                :year               => '2012',
                :verification_value => '123'
              )

if credit_card.valid?

  gateway = ActiveMerchant::Billing::GestpayGateway.new(
              :shop_login => 'GESPAY46234'
            )

  response = gateway.authorize(amount, credit_card, {:transaction_id => '123'})
  
  if response.success?
    response = gateway.capture(amount, response[:PAY1_BANKTRANSACTIONID], {:transaction_id => '123'})
    # response = gateway.void(response[:PAY1_BANKTRANSACTIONID], {:transaction_id => '123'})
    # response = gateway.refund(amount, response[:PAY1_BANKTRANSACTIONID], {:transaction_id => '123'})
    response = gateway.renounce(response[:PAY1_BANKTRANSACTIONID], {:transaction_id => '123'})
    
    puts "Successfully charged $#{sprintf("%.2f", amount / 100)} to the credit card #{credit_card.display_number}"
  else
    raise StandardError, response.message
  end
end
class GestpayTest < Test::Unit::TestCase
  def setup
    @gateway = GestpayGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of 
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
  end
  
  # Place raw failed response from gateway here
  def failed_purcahse_response
  end
end
