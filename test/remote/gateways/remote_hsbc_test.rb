require 'test_helper'

class RemoteHsbcTest < Test::Unit::TestCase
  

  def setup
    Money.default_currency = "GBP"
    
    @gateway = HsbcGateway.new(fixtures(:hsbc).merge({:test => true}))
    
    @amount = 100.to_money
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => Time.now.to_i,
      :billing_address => address,
      :description => 'Store Purchase',
    }
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end
  
  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response = @gateway.capture(@amount, nil, @options)
    assert_success response
  end
  
  def test_successful_authorize_capture_and_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response = @gateway.capture(@amount, nil, @options)
    assert response = @gateway.void(@amount, nil, @options)
    assert_success response
  end
  
  # def test_successful_purchase
  #   assert response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  # end
  # 
  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end
  # 
  # def test_authorize_and_capture
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options)
  #   assert_success auth
  #   assert_equal 'Success', auth.message
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization)
  #   assert_success capture
  # end
  # 
  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end
  # 
  # def test_invalid_login
  #   gateway = HsbcGateway.new(
  #               :login => '',
  #               :password => ''
  #             )
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  # end
end
