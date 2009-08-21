require 'test_helper'
require 'nokogiri'
require 'curb'

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
      :number => "valid_number",
      :month => 8,
      :year => 2010,
      :first_name => "Name",
      :last_name => "Last Name"
    )
    
    @options = { 
      :shop_transaction_id => Time.now.to_i,
      :billing_address => address,
      :description => 'Store Purchase',
    }
  end

  def test_successful_authorize
    assert @response = @gateway.authorize(@amount, @credit_card, @options)
    if @response.params["vbvrisp"]
      result = Nokogiri::HTML(ssl_get("https://testecomm.sella.it/gestpay/pagamvisa3d.asp?a=#{fixtures(:gestpay)[:shop_login]}&b=#{@response.params["vbvrisp"]}&c=http://medlar.it"))
      action = result.search("form")[0].attribute("action")
      parameters = []
      result.search("form input").each do |el|
        parameters << Curl::PostField.content(el.attribute("name").to_s, el.attribute("value").to_s)
      end
      result = Nokogiri::HTML(Curl::Easy.http_post(action, *parameters).body_str)
      action = result.search("form")[0].attribute("action")
      pares = result.search("form input[name=PaRes]")[0].attribute("value").to_s
      assert @response = @gateway.authorize(@amount, @credit_card, @options.merge({:pares => pares, :transkey => @response.params["transkey"]}))
      assert_success @response
    else
      assert_success @response
    end
  end

  def test_successful_authorize_and_capture
    test_successful_authorize
    assert @response = @gateway.capture(@amount, @response.params["bank_transaction_id"], @options)
    assert_success @response
  end

  def test_successful_authorize_and_void
    test_successful_authorize
    assert @response = @gateway.void(@response.params["bank_transaction_id"], @options)
    assert_success @response
  end

  def test_successful_authorize_capture_and_void
    test_successful_authorize_and_capture
    assert @response = @gateway.void(@response.params["bank_transaction_id"], @options)
    assert_success @response
  end
  
end
