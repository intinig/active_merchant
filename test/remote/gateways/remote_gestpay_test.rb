require 'test_helper'

class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end

class RemoteGestpayTest < Test::Unit::TestCase
  include ActiveMerchant::PostsData
  
  def setup
    Money.default_currency = "EUR"
    
    @gateway = GestpayGateway.new(fixtures(:gestpay).merge({:test => true}))
    
    @amount = 1.to_money
    @credit_card = CreditCard.new(
      :number => "4532231440119212",
      :month => 8,
      :year => 2010,
      :first_name => "Giuseppe",
      :last_name => "Pellicani"
    )
    
    @options = { 
      :shop_transaction_id => Time.now.to_i,
      :billing_address => address,
      :description => 'Store Purchase',
    }
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    if response.params["vbvrisp"]
      result = ssl_get("https://testecomm.sella.it/gestpay/pagamvisa3d.asp?a=#{fixtures(:gestpay)[:shop_login]}&b=#{response.params["vbvrisp"]}&c=http://medlar.it")
    end
    puts result.match(/action="(.*)" method/)[1]
    # assert_success response
  end

  # def test_successful_authorize_with_pas
  #   assert response = @gateway.authorize(@amount, @credit_card, @options.merge({:payer_authentication_code => "gemelli"}))
  #   assert_success response
  # end
  # 
  # def test_successful_authorize_and_capture
  #   assert response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert response = @gateway.capture(@amount, nil, @options)
  #   assert_success response
  # end
  # 
  # def test_successful_authorize_capture_and_void
  #   assert response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert response = @gateway.capture(@amount, nil, @options)
  #   assert response = @gateway.void(@amount, nil, @options)
  #   assert_success response
  # end
  # 
  # def test_successful_purchase
  #   assert response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  # end
  # 
  # def test_successful_refund
  #   assert response = @gateway.refund(@amount, @credit_card, @options)
  #   assert_success response
  # end
  
end
