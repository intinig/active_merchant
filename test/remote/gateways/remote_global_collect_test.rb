require File.join(File.dirname(__FILE__), '../../test_helper')

class RemoteGlobalCollectTest < Test::Unit::TestCase
  

  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect))
    
    @amount = 100
    @credit_card = credit_card('4012001011000771')
    @declined_card = credit_card('4000377011112220')
    
    @options = { 
      :order_id => Time.now.to_i,
      :address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response = @gateway.capture(@amount, nil, @options)
    assert_success response
  end
  
  # explorative test
  # def test_3dsecure_response
  #   assert response = @gateway.authorize(@amount, @credit_card, @options)
  # end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end
  
  def test_successful_authorize_capture_and_credit
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response = @gateway.capture(@amount, nil, @options)
    assert_success response
    # assert response = @gateway.credit(@amount, @options[:order_id])
    # assert_success response
  end
  
  def test_invalid_login
    gateway = GlobalCollectGateway.new(
                :merchant => '',
                :ip => '123.123.123.123'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'NO MERCHANTID ACTION INSERT_ORDERWITHPAYMENT (130) IS NOT ALLOWED', response.message
  end
end
