require File.dirname(__FILE__) + '/../../test_helper'

class GlobalCollectTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalCollectGateway.new(
      :merchant => '1',
      :ip => '123.123.123.123',
      :test => true
     )

    @credit_card = credit_card(4567350000427977, :month => 12, :year => 2006, :type => :visa)
    @amount = Money.new(29990, 'USD')
    
    @options = { 
      :order_id => '9998990013',
      :description => 'Store Purchase',
      :address => {
        :country => 'IT'
      }
    }
        
  end
  
  def test_test?
    g = GlobalCollectGateway.new(:merchant => '1', :ip => '123.123.123.123', :test => false)
    assert ! g.send(:test?)
    g = GlobalCollectGateway.new(:merchant => '1', :ip => '123.123.123.123', :test => true)
    assert g.send(:test?)
  end
  
  def test_global_collect_url_should_return_correct_urls    
    assert_equal 'https://ps.gcsip.com/wdl/wdl', create_gateway.send(:global_collect_url)
    assert_equal 'https://ps.gcsip.nl/wdl/wdl', create_gateway(true).send(:global_collect_url)
    assert_equal 'https://ca.gcsip.com/wdl/wdl', create_gateway(false, true).send(:global_collect_url)
    assert_equal 'https://ca.gcsip.nl/wdl/wdl', create_gateway(true, true).send(:global_collect_url)
  end
    
  def test_authorize_should_build_successful_request
    request = @gateway.send(:build_authorize_request, Money.new(29990, 'EUR'), @credit_card, {:order_id => '9998990013', :address => {:country => 'NL'}})
    assert_equal_xml successful_authorize_request, request
  end
  
  # explorative test
  def test_decoding_responses
    response = REXML::Document.new(successful_insert_order_with_payment_response)
    assert_equal 'OK', response.root.elements["REQUEST/RESPONSE/RESULT"].text
  end
  
  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_insert_order_with_payment_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '123', response.authorization
    assert response.test?
  end
  
  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_insert_order_with_payment_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end
  
  def test_get_order_status_should_build_successful_request
    request = @gateway.send(:build_get_order_status_request, @options[:order_id])
  end
  
  def test_capture_should_build_successful_request
    request = @gateway.send(:build_capture_request, Money.new(29990, 'EUR'), 9998990013, 1)
    assert_equal_xml successful_set_payment_request, request
  end
  
  def test_successful_capture
    @gateway.expects(:ssl_post).at_least(2).returns(successful_get_order_status_response, successful_set_payment_response)
    
    assert response = @gateway.capture(@amount, nil, @options)
    assert_instance_of Response, response
    assert_success response
  end
  
  def test_failed_capture_wrong_order
    @gateway.expects(:ssl_post).returns(failed_get_order_status_response)
    
    assert response = @gateway.capture(@amount, nil, @options)
    assert_failure response
  end
  
  def test_failed_capture_correct_order
    @gateway.expects(:ssl_post).at_least(2).returns(successful_get_order_status_response, failed_set_payment_response)
    
    assert response = @gateway.capture(@amount, nil, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).at_least(2).returns(successful_insert_order_with_payment_response, successful_set_payment_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
  end
  
  def test_failed_purchase_no_authorization
    @gateway.expects(:ssl_post).returns(failed_insert_order_with_payment_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_failed_purchase_no_set_payment
    @gateway.expects(:ssl_post).at_least(2).returns(successful_insert_order_with_payment_response, failed_set_payment_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response  
  end
  
  def test_successul_credit
  end
  
  def test_unsuccessful_credit
  end
  
  def test_successful_void
  end
  
  def test_unsuccessful_void
  end

  private
  
  def create_gateway(test = false, security = :ip_check)
    GlobalCollectGateway.new(:merchant => '1', :ip => '123.123.123.123', :test => test, :security => security)
  end
  
  def successful_get_order_status_request
    <<-XML
    <XML> 
     <REQUEST> 
      <ACTION>GET_ORDERSTATUS</ACTION> 
      <META> 
       <MERCHANTID>1</MERCHANTID> 
       <IPADDRESS>123.123.123.123</IPADDRESS> 
       <VERSION>1.0</VERSION> 
      </META> 
      <PARAMS> 
       <ORDER> 
        <ORDERID>9998890004</ORDERID> 
       </ORDER> 
      </PARAMS> 
     </REQUEST> 
    </XML> 
    XML
  end
  
  def successful_get_order_status_response
    <<-XML
    <XML> 
     <REQUEST> 
      <ACTION>GET_ORDERSTATUS</ACTION> 
      <META> 
       <MERCHANTID>1</MERCHANTID> 
       <IPADDRESS>123.123.123.123</IPADDRESS> 
       <VERSION>1.0</VERSION> 
       <REQUESTIPADDRESS>123.123.123.123</REQUESTIPADDRESS> 
      </META> 
      <PARAMS> 
       <ORDER> 
        <ORDERID>9998890004</ORDERID> 
       </ORDER> 
      </PARAMS> 
      <RESPONSE> 
       <RESULT>OK</RESULT> 
       <META> 
        <RESPONSEDATETIME>20040718145902</RESPONSEDATETIME> 
        <REQUESTID>245</REQUESTID> 
       </META> 
       <ROW> 
         <MERCHANTID>1</MERCHANTID> 
        <ORDERID>9998890004</ORDERID> 
        <EFFORTID>1</EFFORTID> 
        <ATTEMPTID>1</ATTEMPTID> 
        <PAYMENTREFERENCE>900100000010</PAYMENTREFERENCE> 
        <MERCHANTREFERENCE></MERCHANTREFERENCE> 
        <STATUSID>99999</STATUSID> 
        <PAYMENTMETHODID>1</PAYMENTMETHODID>
        <PAYMENTPRODUCTID>0</PAYMENTPRODUCTID> 
        <CURRENCYCODE>EUR</CURRENCYCODE> 
        <AMOUNT>2345</AMOUNT> 
        <STATUSDATE>20030828183053</STATUSDATE> 
        <ERRORNUMBER></ERRORNUMBER> 
        <ERRORMESSAGE></ERRORMESSAGE> 
       </ROW> 
      </RESPONSE> 
     </REQUEST> 
    </XML> 
    XML
  end
 
  def failed_get_order_status_response
    <<-XML
    <XML> 
     <REQUEST> 
      <ACTION>GET_ORDERSTATUS</ACTION> 
      <META> 
       <MERCHANTID>1</MERCHANTID> 
       <IPADDRESS>123.123.123.123</IPADDRESS> 
       <VERSION>1.0</VERSION> 
       <REQUESTIPADDRESS>123.123.123.123</REQUESTIPADDRESS> 
      </META> 
      <PARAMS> 
       <ORDER> 
        <ORDERID>9998890004</ORDERID> 
       </ORDER> 
      </PARAMS> 
      <RESPONSE> 
       <RESULT>NOK</RESULT> 
       <META> 
        <RESPONSEDATETIME>20040718145902</RESPONSEDATETIME> 
        <REQUESTID>245</REQUESTID> 
       </META> 
       <ROW> 
         <MERCHANTID>1</MERCHANTID> 
        <ORDERID>9998890004</ORDERID> 
        <EFFORTID>1</EFFORTID> 
        <ATTEMPTID>1</ATTEMPTID> 
        <PAYMENTREFERENCE>900100000010</PAYMENTREFERENCE> 
        <MERCHANTREFERENCE></MERCHANTREFERENCE> 
        <STATUSID>99999</STATUSID> 
        <PAYMENTMETHODID>1</PAYMENTMETHODID>
        <PAYMENTPRODUCTID>0</PAYMENTPRODUCTID> 
        <CURRENCYCODE>EUR</CURRENCYCODE> 
        <AMOUNT>2345</AMOUNT> 
        <STATUSDATE>20030828183053</STATUSDATE> 
        <ERRORNUMBER></ERRORNUMBER> 
        <ERRORMESSAGE></ERRORMESSAGE> 
       </ROW> 
      </RESPONSE> 
     </REQUEST> 
    </XML> 
    XML
  end
 
  def successful_authorize_request
    <<-XML
    <XML>
      <REQUEST>
        <ACTION>INSERT_ORDERWITHPAYMENT</ACTION>
        <META>
          <MERCHANTID>1</MERCHANTID>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <VERSION>1.0</VERSION>
        </META>
        <PARAMS>
          <ORDER>
            <ORDERID>9998990013</ORDERID>
            <MERCHANTREFERENCE>9998990013</MERCHANTREFERENCE>
            <AMOUNT>29990</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>en</LANGUAGECODE>
          </ORDER>
          <PAYMENT>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <AMOUNT>29990</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <CREDITCARDNUMBER>4567350000427977</CREDITCARDNUMBER>
            <EXPIRYDATE>1206</EXPIRYDATE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>en</LANGUAGECODE>
          </PAYMENT>
        </PARAMS>
      </REQUEST>
    </XML>
    XML
  end
  
  def successful_set_payment_request
    <<-XML
    <XML> 
     <REQUEST> 
      <ACTION>SET_PAYMENT</ACTION> 
      <META> 
        <MERCHANTID>1</MERCHANTID> 
        <IPADDRESS>123.123.123.123</IPADDRESS> 
        <VERSION>1.0</VERSION> 
      </META> 
          <PARAMS> 
           <PAYMENT> 
              <ORDERID>9998990013</ORDERID> 
                <EFFORTID>1</EFFORTID> 
                <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID> 
             </PAYMENT> 
      </PARAMS> 
     </REQUEST> 
    </XML> 
    XML
  end
  
  def successful_set_payment_response
    <<-XML
    <XML> 
     <REQUEST> 
        <ACTION>SET_PAYMENT</ACTION> 
          <META> 
           <IPADDRESS>123.123.123.123</IPADDRESS> 
             <MERCHANTID>1</MERCHANTID> 
             <VERSION>1.0</VERSION> 
          </META> 
          <PARAMS> 
           <PAYMENT> 
              <ORDERID>9998990011</ORDERID> 
                <EFFORTID>1</EFFORTID> 
                <PAYMENTPRODUCTID>701</PAYMENTPRODUCTID> 
             </PAYMENT> 
      </PARAMS> 
          <RESPONSE> 
           <RESULT>OK</RESULT> 
           <META> 
             <RESPONSEDATETIME>20040719145902</RESPONSEDATETIME> 
             <REQUESTID>246</REQUESTID> 
           </META> 
      </RESPONSE> 
     </REQUEST> 
    </XML> 
    XML
  end
  
  def failed_set_payment_response
    <<-XML
    <XML> 
     <REQUEST> 
        <ACTION>SET_PAYMENT</ACTION> 
          <META> 
           <IPADDRESS>123.123.123.123</IPADDRESS> 
             <MERCHANTID>1</MERCHANTID> 
             <VERSION>1.0</VERSION> 
          </META> 
          <PARAMS> 
           <PAYMENT> 
              <ORDERID>9998990011</ORDERID> 
                <EFFORTID>1</EFFORTID> 
                <PAYMENTPRODUCTID>701</PAYMENTPRODUCTID> 
             </PAYMENT> 
      </PARAMS> 
      <RESPONSE> 
      <RESULT>NOK</RESULT> 
         <META> 
          <RESPONSEDATETIME>20040719145902</RESPONSEDATETIME> 
            <REQUESTID>246</REQUESTID> 
         </META> 
         <ERROR> 
          <CODE>410110</CODE> 
            <MESSAGE>REQUEST 257 UNKNOWN ORDER OR NOT PENDING</MESSAGE> 
         </ERROR> 
      </RESPONSE> 
     </REQUEST> 
    </XML> 
    XML
  end
  
  def successful_insert_order_with_payment_response
    <<-XML
    <XML>
      <REQUEST>
        <ACTION>INSERT_ORDERWITHPAYMENT</ACTION>
        <META>
          <MERCHANTID>1</MERCHANTID>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <VERSION>1.0</VERSION>
          <REQUESTIPADDRESS>123.123.123.123</REQUESTIPADDRESS>
        </META>
        <PARAMS>
          <ORDER>
            <ORDERID>9998990013</ORDERID>
            <MERCHANTREFERENCE>9998990013</MERCHANTREFERENCE>
            <AMOUNT>29990</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>nl</LANGUAGECODE>
          </ORDER>
          <PAYMENT>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <AMOUNT>2345</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <CREDITCARDNUMBER>4567350000427977</CREDITCARDNUMBER>
            <EXPIRYDATE>1206</EXPIRYDATE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>nl</LANGUAGECODE>
          </PAYMENT>
        </PARAMS>
        <RESPONSE>
          <RESULT>OK</RESULT>
          <META>
            <RESPONSEDATETIME>20040718145902</RESPONSEDATETIME>
            <REQUESTID>245</REQUESTID>
          </META>
          <ROW>
            <MERCHANTID>1</MERCHANTID>
            <ORDERID>9998990013</ORDERID>
            <EFFORTID>1</EFFORTID>
            <ATTEMPTID>1</ATTEMPTID>
            <STATUSID>800</STATUSID>
            <STATUSDATE>20030829171416</STATUSDATE>
            <PAYMENTREFERENCE>185800005380</PAYMENTREFERENCE>
            <ADDITIONALREFERENCE>19998990013</ADDITIONALREFERENCE>
            <AUTHORISATIONCODE>123</AUTHORISATIONCODE>
          </ROW>
        </RESPONSE>
      </REQUEST>
    </XML>
    XML
  end
  
  def failed_insert_order_with_payment_response
    <<-XML
    <?xml version="1.0"?>
    <RESPONSE>
      <RESULT>NOK</RESULT>
      <META>
        <RESPONSEDATETIME>20040718145902</RESPONSEDATETIME>
        <REQUESTID>245</REQUESTID>
      </META>
      <ERROR>
        <CODE>21000020</CODE>
        <MESSAGE>
        REQUEST 1212121 VALUE 4567350000427976 OF FIELD CREDITCARDNUMBER DID NOT PASS THE 
        LUHNCHECK 
          </MESSAGE>
      </ERROR>
    </RESPONSE>
    XML
  end
  
  def prepare_for_comparison(string)
    string.gsub(/\s{2,}/, ' ').gsub(/(\/?)> </, "#{$1}><")
  end
  
  def assert_equal_xml(expected, actual)
    assert_equal prepare_for_comparison(REXML::Document.new(expected).root.to_s), prepare_for_comparison(REXML::Document.new(actual).root.to_s)
  end
end
