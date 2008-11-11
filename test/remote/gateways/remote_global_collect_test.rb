require File.join(File.dirname(__FILE__), '../../test_helper')

class RemoteGlobalCollectTest < Test::Unit::TestCase
  

  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect))
    
    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000377011112220')
    
    @options = { 
      :order_id => Time.now.to_i,
      :address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    puts response.inspect
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "REQUEST #{response.params["request_id"]} VALUE ************2220 OF FIELD CREDITCARDNUMBER DID NOT PASS THE LUHNCHECK", response.message, response.inspect
  end

  # def test_authorize_and_capture
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options)
  #   assert_success auth
  #   assert_equal 'Success', auth.message
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization)
  #   assert_success capture
  # end

  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end

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
