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
  
  def test_get_key_from_response_should_fetch_key
    r = REXML::Document.new(successful_authorize_response).root.elements
    key = @gateway.send(:get_key_from_response, r, "EngineDocList.EngineDoc.OrderFormDoc.Transaction.CardProcResp.ProcReturnMsg")
    assert_equal "Approved", key, r.inspect
  end
  
  def test_get_message_from_response_should_return_one_message
    r = REXML::Document.new(insufficient_permission_response).root.elements
    message = @gateway.send(:get_message_from_response, r)
    assert_equal "Insufficient permissions to perform requested operation.", message
  end

  def test_get_message_from_response_should_return_multiple_messages
    r = REXML::Document.new(forged_multi_message_response).root.elements
    message = @gateway.send(:get_message_from_response, r)
    assert_equal "Insufficient permissions to perform requested operation., Insufficient permissions to perform requested operation.", message
  end
  
  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert response.test?
  end
    
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
  <?xml version="1.0" encoding="UTF-8"?>
  <EngineDocList>
   <DocVersion DataType="String">1.0</DocVersion>
   <EngineDoc>
    <ContentType DataType="String">OrderFormDoc</ContentType>
    <DocumentId DataType="String">4a12be4b-c307-3002-002b-0003ba1d84d5</DocumentId>
    <Instructions>
     <Pipeline DataType="String">Payment</Pipeline>

    </Instructions>
    <MessageList>

    </MessageList>
    <OrderFormDoc>
     <Consumer>
      <PaymentMech>
       <CreditCard>
        <Expires DataType="ExpirationDate">05/07</Expires>
        <Number DataType="String">4111111111111111</Number>

       </CreditCard>
       <Type DataType="String">CreditCard</Type>

      </PaymentMech>

     </Consumer>
     <DateTime DataType="DateTime">1248267525896</DateTime>
     <FraudInfo>
      <FraudResult DataType="String">None</FraudResult>
      <FraudResultCode DataType="S32">0</FraudResultCode>
      <OrderScore DataType="Numeric" Precision="0">0</OrderScore>
      <StrategyList>
       <Strategy>
        <FraudAction DataType="String">None</FraudAction>
        <StrategyId DataType="S32">1</StrategyId>
        <StrategyName DataType="String">My Rules</StrategyName>
        <StrategyOwnerId DataType="S32">359</StrategyOwnerId>
        <StrategyScore DataType="Numeric" Precision="0">0</StrategyScore>

       </Strategy>

      </StrategyList>
      <TotalScore DataType="Numeric" Precision="0">0</TotalScore>

     </FraudInfo>
     <GroupId DataType="String">order_number_1</GroupId>
     <Id DataType="String">order_number_1</Id>
     <Mode DataType="String">Y</Mode>
     <Transaction>
      <AuthCode DataType="String">925967</AuthCode>
      <CardProcResp>
       <CcErrCode DataType="S32">1</CcErrCode>
       <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
       <ProcReturnCode DataType="String">1</ProcReturnCode>
       <ProcReturnMsg DataType="String">Approved</ProcReturnMsg>
       <Status DataType="String">1</Status>

      </CardProcResp>
      <CardholderPresentCode DataType="S32">7</CardholderPresentCode>
      <CurrentTotals>
       <Totals>
        <Total DataType="Money" Currency="826">100</Total>

       </Totals>

      </CurrentTotals>
      <Id DataType="String">4a12be4b-c308-3002-002b-0003ba1d84d5</Id>
      <InputEnvironment DataType="S32">4</InputEnvironment>
      <SecurityIndicator DataType="S32">7</SecurityIndicator>
      <TerminalInputCapability DataType="S32">1</TerminalInputCapability>
      <Type DataType="String">Auth</Type>

     </Transaction>

    </OrderFormDoc>
    <Overview>
     <AuthCode DataType="String">925967</AuthCode>
     <CcErrCode DataType="S32">1</CcErrCode>
     <CcReturnMsg DataType="String">Approved.</CcReturnMsg>
     <DateTime DataType="DateTime">1248267525896</DateTime>
     <FraudStatus DataType="String">None</FraudStatus>
     <FraudWeight DataType="Numeric" Precision="0">0</FraudWeight>
     <Mode DataType="String">Y</Mode>
     <OrderId DataType="String">order_number_1</OrderId>
     <TransactionId DataType="String">4a12be4b-c308-3002-002b-0003ba1d84d5</TransactionId>
     <TransactionStatus DataType="String">A</TransactionStatus>

    </Overview>
    <User>
     <Alias DataType="String">UK11111199GBP</Alias>
     <ClientId DataType="S32">359</ClientId>
     <EffectiveAlias DataType="String">UK11111199GBP</EffectiveAlias>
     <EffectiveClientId DataType="S32">359</EffectiveClientId>
     <Name DataType="String">prada</Name>
     <Password DataType="String">XXXXXXX</Password>

    </User>

   </EngineDoc>
   <TimeIn DataType="DateTime">1248267525887</TimeIn>
   <TimeOut DataType="DateTime">1248267525987</TimeOut>

  </EngineDocList>
  XMLEOF
  end

  def insufficient_permission_response
    <<-XMLEOF
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
     <DocVersion DataType="String">1.0</DocVersion>
     <EngineDoc>
      <ContentType DataType="String">OrderFormDoc</ContentType>
      <DocumentId DataType="String">4a12be4b-c2fc-3002-002b-0003ba1d84d5</DocumentId>
      <Instructions>
       <Pipeline DataType="String">Payment</Pipeline>

      </Instructions>
      <MessageList>
       <MaxSev DataType="S32">6</MaxSev>
       <Message>
        <AdvisedAction DataType="S32">16</AdvisedAction>
        <Audience DataType="String">Merchant</Audience>
        <Component DataType="String">Director</Component>
        <ContextId DataType="String">Director</ContextId>
        <DataState DataType="S32">3</DataState>
        <FileLine DataType="S32">902</FileLine>
        <FileName DataType="String">CcxInput.cpp</FileName>
        <FileTime DataType="String">14:32:10Oct 13 2007</FileTime>
        <ResourceId DataType="S32">7</ResourceId>
        <Sev DataType="S32">6</Sev>
        <Text DataType="String">Insufficient permissions to perform requested operation.</Text>

       </Message>

      </MessageList>
      <OrderFormDoc>
       <Consumer>
        <PaymentMech>
         <CreditCard>
          <Expires DataType="ExpirationDate">05/07</Expires>
          <Number DataType="String">4111111111111111</Number>

         </CreditCard>
         <Type DataType="String">CreditCard</Type>

        </PaymentMech>

       </Consumer>
       <Id DataType="String">order_number_1</Id>
       <Mode DataType="String">P</Mode>
       <Transaction>
        <CurrentTotals>
         <Totals>
          <Total DataType="Money" Currency="826">100</Total>

         </Totals>

        </CurrentTotals>
        <Type DataType="String">Auth</Type>

       </Transaction>

      </OrderFormDoc>
      <User>
       <ClientId DataType="S32">99999</ClientId>
       <Name DataType="String">prada</Name>
       <Password DataType="String">ab123456</Password>

      </User>

     </EngineDoc>
     <TimeIn DataType="DateTime">1248267232472</TimeIn>
     <TimeOut DataType="DateTime">1248267232481</TimeOut>

    </EngineDocList>
    XMLEOF
  end

  def forged_multi_message_response
    <<-XMLEOF
    <?xml version="1.0" encoding="UTF-8"?>
    <EngineDocList>
     <DocVersion DataType="String">1.0</DocVersion>
     <EngineDoc>
      <ContentType DataType="String">OrderFormDoc</ContentType>
      <DocumentId DataType="String">4a12be4b-c2fc-3002-002b-0003ba1d84d5</DocumentId>
      <Instructions>
       <Pipeline DataType="String">Payment</Pipeline>

      </Instructions>
      <MessageList>
       <MaxSev DataType="S32">6</MaxSev>
       <Message>
        <AdvisedAction DataType="S32">16</AdvisedAction>
        <Audience DataType="String">Merchant</Audience>
        <Component DataType="String">Director</Component>
        <ContextId DataType="String">Director</ContextId>
        <DataState DataType="S32">3</DataState>
        <FileLine DataType="S32">902</FileLine>
        <FileName DataType="String">CcxInput.cpp</FileName>
        <FileTime DataType="String">14:32:10Oct 13 2007</FileTime>
        <ResourceId DataType="S32">7</ResourceId>
        <Sev DataType="S32">6</Sev>
        <Text DataType="String">Insufficient permissions to perform requested operation.</Text>

       </Message>
       <Message>
        <AdvisedAction DataType="S32">16</AdvisedAction>
        <Audience DataType="String">Merchant</Audience>
        <Component DataType="String">Director</Component>
        <ContextId DataType="String">Director</ContextId>
        <DataState DataType="S32">3</DataState>
        <FileLine DataType="S32">902</FileLine>
        <FileName DataType="String">CcxInput.cpp</FileName>
        <FileTime DataType="String">14:32:10Oct 13 2007</FileTime>
        <ResourceId DataType="S32">7</ResourceId>
        <Sev DataType="S32">6</Sev>
        <Text DataType="String">Insufficient permissions to perform requested operation.</Text>

       </Message>

      </MessageList>
      <OrderFormDoc>
       <Consumer>
        <PaymentMech>
         <CreditCard>
          <Expires DataType="ExpirationDate">05/07</Expires>
          <Number DataType="String">4111111111111111</Number>

         </CreditCard>
         <Type DataType="String">CreditCard</Type>

        </PaymentMech>

       </Consumer>
       <Id DataType="String">order_number_1</Id>
       <Mode DataType="String">P</Mode>
       <Transaction>
        <CurrentTotals>
         <Totals>
          <Total DataType="Money" Currency="826">100</Total>

         </Totals>

        </CurrentTotals>
        <Type DataType="String">Auth</Type>

       </Transaction>

      </OrderFormDoc>
      <User>
       <ClientId DataType="S32">99999</ClientId>
       <Name DataType="String">prada</Name>
       <Password DataType="String">ab123456</Password>

      </User>

     </EngineDoc>
     <TimeIn DataType="DateTime">1248267232472</TimeIn>
     <TimeOut DataType="DateTime">1248267232481</TimeOut>

    </EngineDocList>
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
