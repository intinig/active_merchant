require File.dirname(__FILE__) + '/../../test_helper'

class HsbcTest < Test::Unit::TestCase
  def setup
    @gateway = HsbcGateway.new(
      :client_id => '359',
      :name => 'prada',
      :password => 'ab123456',
      :test => true
     )

    @credit_card = credit_card(4567350000427977, :month => 05, :year => 2007, :type => :visa)
    @amount = Money.new(100, 'GBP')
    
    @options = { 
      :order_id => 'order_number_2'
    }

  end

  def test_should_require_client_id
    begin
      g = HsbcGateway.new
    rescue Exception => e
      assert_equal "#<ArgumentError: Missing required parameter: client_id>", e.inspect
    end
  end
  
  def test_should_require_name
    begin
      g = HsbcGateway.new(:client_id => '359')
    rescue Exception => e
      assert_equal "#<ArgumentError: Missing required parameter: name>", e.inspect
    end
  end

  def test_should_require_password
    begin
      g = HsbcGateway.new(:client_id => '359', :name => 'prada')
    rescue Exception => e
      assert_equal "#<ArgumentError: Missing required parameter: password>", e.inspect
    end
  end

  def test_should_build_successful_authorize_request
    request = @gateway.send(:build_authorize_request, @amount, @credit_card, @options)
    assert_equal_xml successful_authorize_request, request
  end
  
  def test_should_correctly_select_the_transaction_mode
    assert_equal "Y", @gateway.instance_variable_get(:@options)[:mode]
    g = gateway_with_mode(nil)
    assert_equal "P", g.instance_variable_get(:@options)[:mode]
    g = gateway_with_mode("N")
    assert_equal "N", g.instance_variable_get(:@options)[:mode]
    begin
      g = gateway_with_mode("P", true) 
    rescue Exception => e
      assert_equal "#<RuntimeError: Cannot use mode \"P\" in test mode>", e.inspect
    end    
  end
  
  # def test_successful_authorize
  #   @gateway.expects(:ssl_post).returns(successful_authorize_response)
  #   
  #   assert response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_instance_of Response, response
  #   assert_success response
  #   
  #   # Replace with authorization number from the successful response
  #   assert_equal '123', response.authorization
  #   assert response.test?
  # end
  
  # def test_failed_authorize
  #   @gateway.expects(:ssl_post).returns(failed_insert_order_with_payment_response)
  #   
  #   assert response = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert response.test?
  # end
    # def prepare_for_comparison(string)
  #   string.gsub(/\s{2,}/, ' ').gsub(/(\/?)> </, "#{$1}><")
  # end
  # 
  # def assert_equal_xml(expected, actual)
  #   assert_equal prepare_for_comparison(REXML::Document.new(expected).root.to_s), prepare_for_comparison(REXML::Document.new(actual).root.to_s)
  # end
  
  protected
  def successful_authorize_request
  <<-XMLEOF
  <?xml version="1.0" encoding="UTF-8" ?> 
    <EngineDocList>
      <DocVersion DataType="String">1.0</DocVersion>
      <EngineDoc>
        <ContentType DataType="String">OrderFormDoc</ContentType>
        <User>
          <ClientId DataType="S32">359</ClientId>
          <Name DataType="String">prada</Name>
          <Password DataType="String">ab123456</Password>
        </User>
        <Instructions>
          <Pipeline DataType="String">Payment</Pipeline>
        </Instructions>
        <OrderFormDoc>
          <Id DataType="String">order_number_2</Id>
          <Mode DataType="String">Y</Mode>
          <Consumer>
            <PaymentMech>
              <Type DataType="String">CreditCard</Type>
              <CreditCard>
                <Number DataType="String">4567350000427977</Number>
                <Expires DataType="ExpirationDate" Locale="826">05/07</Expires>
             </CreditCard>
            </PaymentMech>
          </Consumer>
          <Transaction>
            <Type DataType="String">Auth</Type>
            <CurrentTotals>
              <Totals>
                <Total DataType="Money" Currency="826">100</Total>
              </Totals>
            </CurrentTotals>
          </Transaction>
        </OrderFormDoc>
      </EngineDoc>
    </EngineDocList>
    XMLEOF
  end
  
  def successful_authorize_response
  <<-XMLEOF
  XMLEOF
  end

  def prepare_for_comparison(string)
    string.gsub(/\s{2,}/, ' ').gsub(/(\/?)> </, "#{$1}><")
  end
  
  def assert_equal_xml(expected, actual)
    assert_equal prepare_for_comparison(REXML::Document.new(expected).root.to_s), prepare_for_comparison(REXML::Document.new(actual).root.to_s)
  end
  
  def gateway_with_mode(mode, test = false)
    HsbcGateway.new(
      :client_id => '359',
      :name => 'prada',
      :password => 'ab123456',
      :mode => mode,
      :test => test
    )
  end
  
end
