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
  
  # a symbol can't start with a number. so we use secure_3d instead of 3d_secure
  def test_authorize_should_build_correct_do_checkenrollment_request_if_secure_3d_if_true
    # I use an other gateway because the secure_3d option is used just here
    gateway = GlobalCollectGateway.new( :merchant => '1', :ip => '123.123.123.123', :test => true, :secure_3d => true)
    request = gateway.send(:build_do_checkenrollment_request, Money.new(29990, 'EUR'), @credit_card, {:order_id => '9998990013', :address => {:country => 'NL'}})
    assert_equal_xml successful_do_checkenrollment_request, request
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
  
  def test_successful_authorize_with_fraud_code
    gateway = GlobalCollectGateway.new( :merchant => '1', :ip => '123.123.123.123', :test => true, :secure_3d => true)
    gateway.expects(:ssl_post).at_least(2).returns(successful_insert_order_with_payment_and_fraud_code_response, successful_do_checkenrollment_response)
    assert response = gateway.authorize(@amount, @credit_card, @options)
    
    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '123', response.authorization
    assert response.test?
  end
  
  def test_authorize_should_not_call_do_checkenrollment_if_secure_3d_is_false
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

  def test_credit_should_build_correct_request_step_one
    request = @gateway.send(:build_do_refund_request, '8800100375', 'GB')
    assert_equal_xml successful_do_refund_request, request
  end

  def test_credit_should_build_correct_request_step_two
    request = @gateway.send(:build_set_refund_request, '8800100375', '701')
    assert_equal_xml successful_set_refund_request, request
  end
  
  def test_successful_credit
    @gateway.expects(:ssl_post).at_least(3).returns(successful_get_order_status_response, successful_do_refund_response, successful_set_refund_response)
    
    assert response = @gateway.credit(@amount, @options[:order_id])
    assert_instance_of Response, response
    assert_success response
  end
  
  def test_failed_credit_correct_order_wrong_something_else
    @gateway.expects(:ssl_post).at_least(2).returns(successful_get_order_status_response, failed_do_refund_response)
    
    assert response = @gateway.credit(@amount, @options[:order_id])
    assert_instance_of Response, response
    assert_failure response      
  end
  
  def test_void_should_build_correct_request
  end
  
  def test_successful_void
  end
  
  def test_failed_void
  end
  
  def test_parse_order_should_parse_get_order_status
    response = @gateway.send(:parse_order, successful_get_order_status_response)
    assert_equal '9998890004', response[:order_id]
    assert response[:success]
    assert_equal '245', response[:request_id]
    assert_equal '1', response[:merchant_id]
    assert_equal '1', response[:attempt_id]
    assert_equal '900100000010', response[:payment_reference]
    assert_equal '123', response[:merchant_reference]
    assert_equal '99999', response[:status_id]
    assert_equal '1', response[:payment_method_id]
    assert_equal '0', response[:payment_product_id]
    assert_equal 'EUR', response[:currency_code] 
    assert_equal '2345', response[:amount]
    assert_equal '0', response[:error_number]
    assert_equal '0', response[:error_message]
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
        <MERCHANTREFERENCE>123</MERCHANTREFERENCE> 
        <STATUSID>99999</STATUSID> 
        <PAYMENTMETHODID>1</PAYMENTMETHODID>
        <PAYMENTPRODUCTID>0</PAYMENTPRODUCTID> 
        <CURRENCYCODE>EUR</CURRENCYCODE> 
        <AMOUNT>2345</AMOUNT> 
        <STATUSDATE>20030828183053</STATUSDATE> 
        <ERRORNUMBER>0</ERRORNUMBER> 
        <ERRORMESSAGE>0</ERRORMESSAGE> 
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
  
  def successful_do_checkenrollment_request
    <<-XML
    <XML>
      <REQUEST>
        <ACTION>DO_CHECKENROLLMENT</ACTION>
        <META>
          <MERCHANTID>1</MERCHANTID>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <VERSION>1.0</VERSION>
        </META>
        <PARAMS>
          <PAYMENT>
            <ORDERID>9998990013</ORDERID>            
            <EXPIRYDATE>1206</EXPIRYDATE>
            <CREDITCARDNUMBER>4567350000427977</CREDITCARDNUMBER>
            <CURRENCYCODE>EUR</CURRENCYCODE>            
            <AMOUNT>29990</AMOUNT>
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
  
  def successful_insert_order_with_payment_and_fraud_code_response
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
            <FRAUDRESULT>C</FRAUDRESULT>
            <FRAUDCODE>0100</FRAUDCODE>     
          </ROW>
        </RESPONSE>
      </REQUEST>
    </XML>
    XML
  end  

  def successful_do_checkenrollment_response
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
            <ACSURL>http://acsurl.example.com</ACSURL>
            <PAREQ></PAREQ>
            <XID></XID>
            <MD></MD>
            <PROOFXML></PROOFXML>
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
  
  def successful_do_refund_request
    <<-XML
    <XML> 
        <REQUEST> 
            <ACTION>DO_REFUND</ACTION> 
            <META> 
                <MERCHANTID>1</MERCHANTID> 
                <IPADDRESS>123.123.123.123</IPADDRESS> 
                <VERSION>1.0</VERSION> 
            </META> 
            <PARAMS> 
                <PAYMENT> 
                    <ORDERID>8800100375</ORDERID> 
                    <COUNTRYCODE>GB</COUNTRYCODE> 
                </PAYMENT> 
            </PARAMS> 
        </REQUEST> 
    </XML> 
    XML
  end
  
  def successful_do_refund_response
    <<-XML
    <XML> 
      <REQUEST> 
        <ACTION>DO_REFUND</ACTION> 
        <META> 
          <IPADDRESS>123.123.123.123</IPADDRESS> 
          <MERCHANTID>1</MERCHANTID> 
          <VERSION>1.0</VERSION> 
        </META> 
        <PARAMS> 
          <PAYMENT> 
            <ORDERID>9998990011</ORDERID> 
            <EFFORTID>-1</EFFORTID> 
            <PAYMENTPRODUCTID>701</PAYMENTPRODUCTID> 
          </PAYMENT> 
        </PARAMS> 
      <RESPONSE> 
        <RESULT>OK</RESULT> 
        <META> 
          <REQUESTID>12845</REQUESTID> 
          <RESPONSEDATETIME>20070426151801</RESPONSEDATETIME> 
        </META> 
        <ROW> 
          <STATUSID>900</STATUSID> 
          <EFFORTID>-2</EFFORTID> 
          <PAYMENTREFERENCE>999101117749</PAYMENTREFERENCE> 
          <ATTEMPTID>1</ATTEMPTID> 
          <MERCHANTID>9991</MERCHANTID> 
          <ORDERID>9998990011</ORDERID> 
        </ROW> 
      </RESPONSE> 
    </REQUEST> 
      
    </XML> 
    XML
  end
  
  def failed_do_refund_response
    <<-XML
    <XML> 
    <REQUEST> 
      <ACTION>SET_REFUND</ACTION> 
        <META> 
          <IPADDRESS>123.123.123.123</IPADDRESS> 
          <MERCHANTID>1</MERCHANTID> 
          <VERSION>1.0</VERSION> 
        </META> 
        <PARAMS> 
          <PAYMENT> 
            <ORDERID>9998990011</ORDERID> 
            <EFFORTID>-1</EFFORTID> 
            <PAYMENTPRODUCTID>701</PAYMENTPRODUCTID> 
          </PAYMENT> 
        </PARAMS> 
      <RESPONSE> 
      <RESULT>NOK</RESULT> 
        <META> 
          <REQUESTID>12845</REQUESTID> 
          <RESPONSEDATETIME>20070426151801</RESPONSEDATETIME> 
        </META> 
        <ROW> 
          <STATUSID>900</STATUSID> 
          <EFFORTID>-2</EFFORTID> 
          <PAYMENTREFERENCE>999101117749</PAYMENTREFERENCE> 
          <ATTEMPTID>1</ATTEMPTID> 
          <MERCHANTID>9991</MERCHANTID> 
          <ORDERID>9998990011</ORDERID> 
        </ROW> 
      </RESPONSE> 
    </REQUEST> 
    </XML> 
    XML
  end
  
  def successful_set_refund_request
    <<-XML
    <XML> 
     <REQUEST> 
      <ACTION>SET_REFUND</ACTION> 
      <META> 
             <MERCHANTID>1</MERCHANTID> 
             <IPADDRESS>123.123.123.123</IPADDRESS> 
             <VERSION>1.0</VERSION> 
      </META> 
          <PARAMS> 
           <PAYMENT> 
            <ORDERID>8800100375</ORDERID> 
                <PAYMENTPRODUCTID>701</PAYMENTPRODUCTID> 
                <EFFORTID>-1</EFFORTID> 
             </PAYMENT> 
      </PARAMS> 
     </REQUEST> 
    </XML> 
    XML
  end
  
  def successful_set_refund_response
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
            <EFFORTID>-1</EFFORTID> 
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
  
  def failed_set_refund_response
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
            <EFFORTID>-1</EFFORTID> 
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
  
  def prepare_for_comparison(string)
    string.gsub(/\s{2,}/, ' ').gsub(/(\/?)> </, "#{$1}><")
  end
  
  def assert_equal_xml(expected, actual)
    assert_equal prepare_for_comparison(REXML::Document.new(expected).root.to_s), prepare_for_comparison(REXML::Document.new(actual).root.to_s)
  end
end
