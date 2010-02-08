require File.dirname(__FILE__) + '/../../test_helper'

class GlobalCollectTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalCollectGateway.new(
      :merchant => '1',
      :ip => '123.123.123.123',
      :test => true
     )

    @credit_card = credit_card(4567350000427977, :month => 12, :year => 2006, :type => :visa)
    @amount = 100
    
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
    request = @gateway.send(:build_authorize_request, 100, @credit_card, {:order_id => '9998990013', :address => {:country => 'NL'}})
    assert_equal_xml successful_authorize_request, request
  end
  
  def test_authorize_should_build_successful_hosted_request
    request = @gateway.send(:build_authorize_request, 100, @credit_card, {:order_id => '9998990013', :hosted => true, :address => {:country => 'NL'}, :return_url => 'http://mikamai.com'})
    assert_equal_xml successful_hosted_authorize_request, request
  end
  
  def test_authorize_should_build_successful_request_using_secure_3d
    gateway = GlobalCollectGateway.new( :merchant => '1', :ip => '123.123.123.123', :test => true, :secure_3d => true)
    request = gateway.send(:build_authorize_request, 100, @credit_card, {:order_id => '9998990013', :address => {:country => 'NL'}})
    assert_equal_xml successful_authorize_request_with_secure_3d, request
  end
  
  def test_should_build_correct_do_validate_request
    request = @gateway.send(:build_do_validate_request, 9998890004, 1, 1, '123432kjvdhasiyfdiasyi23u4h2452g')
    assert_equal_xml successful_do_validate_request, request
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
  
  def test_successful_authorize_with_secure_3d
    gateway = GlobalCollectGateway.new( :merchant => '1', :ip => '123.123.123.123', :test => true, :secure_3d => true)
    gateway.expects(:ssl_post).returns(successful_insert_order_with_payment_response)
    
    assert response = gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '123', response.authorization
    assert response.test?
  end
  
  
  def test_successful_authenticate
    @gateway.expects(:ssl_post).returns(successful_do_validate_response)
    
    assert response = @gateway.authenticate(1, 1, '123432kjvdhasiyfdiasyi23u4h2452g', @options)
    assert_instance_of Response, response
    assert_success response
    
    assert response.test?
  end
  
  def test_should_parse_acs_url_on_insert_order_with_payment_response_using_secure_3d
    success, message, options = @gateway.send(:parse, successful_insert_order_with_payment_response_with_secure_3d)
    assert_not_nil options[:acs_url]
  end
  
  def test_should_parse_pareq_on_insert_order_with_payment_response_using_secure_3d
    success, message, options = @gateway.send(:parse, successful_insert_order_with_payment_response_with_secure_3d)
    assert_not_nil options[:pareq]
  end
  
  def test_should_parse_md_on_insert_order_with_payment_response_using_secure_3d
    success, message, options = @gateway.send(:parse, successful_insert_order_with_payment_response_with_secure_3d)
    assert_not_nil options[:md]
  end
  
  def test_should_parse_attempt_id_on_insert_order_with_payment_response_using_secure_3d
    success, message, options = @gateway.send(:parse, successful_insert_order_with_payment_response_with_secure_3d)
    assert_not_nil options[:attempt_id]
  end
  
  def test_should_parse_effort_id_on_insert_order_with_payment_response_using_secure_3d
    success, message, options = @gateway.send(:parse, successful_insert_order_with_payment_response_with_secure_3d)
    assert_not_nil options[:effort_id]
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
    request = @gateway.send(:build_capture_request, 100, 9998990013, 1)
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
  
  def successful_do_validate_request
    <<-XML
      <XML> 
       <REQUEST> 
        <ACTION>DO_VALIDATE</ACTION> 
        <META> 
         <MERCHANTID>1</MERCHANTID> 
         <IPADDRESS>123.123.123.123</IPADDRESS> 
         <VERSION>1.0</VERSION> 
        </META> 
        <PARAMS> 
         <PAYMENT> 
          <ORDERID>9998890004</ORDERID> 
          <EFFORTID>1</EFFORTID> 
          <ATTEMPTID>1</ATTEMPTID> 
          <SIGNEDPARES>123432kjvdhasiyfdiasyi23u4h2452g</SIGNEDPARES>
          <AUTHENTICATIONINDICATOR>1</AUTHENTICATIONINDICATOR>
         </PAYMENT> 
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
            <AMOUNT>100</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>en</LANGUAGECODE>
          </ORDER>
          <PAYMENT>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <AMOUNT>100</AMOUNT>
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
  
  def successful_hosted_authorize_request
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
    				<AMOUNT>100</AMOUNT> 
    				<CURRENCYCODE>EUR</CURRENCYCODE> 
    				<COUNTRYCODE>NL</COUNTRYCODE> 
    				<LANGUAGECODE>en</LANGUAGECODE>
    			</ORDER> 
    			<PAYMENT>
    				<PAYMENTPRODUCTID>1</PAYMENTPRODUCTID> 
    				<AMOUNT>100</AMOUNT> 
    				<CURRENCYCODE>EUR</CURRENCYCODE> 
    				<COUNTRYCODE>NL</COUNTRYCODE> 
    				<LANGUAGECODE>en</LANGUAGECODE>
    				<HOSTEDINDICATOR>1</HOSTEDINDICATOR>
    				<RETURNURL>http://mikamai.com</RETURNURL>
    			</PAYMENT> 
    		</PARAMS>
    	</REQUEST>
    </XML>
    XML
  end
  
  def successful_authorize_request_with_secure_3d
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
            <AMOUNT>100</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>en</LANGUAGECODE>
          </ORDER>
          <PAYMENT>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <AMOUNT>100</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <CREDITCARDNUMBER>4567350000427977</CREDITCARDNUMBER>
            <EXPIRYDATE>1206</EXPIRYDATE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <LANGUAGECODE>en</LANGUAGECODE>
            <AUTHENTICATIONINDICATOR>1</AUTHENTICATIONINDICATOR>
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
            <AMOUNT>100</AMOUNT>
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

  def successful_insert_order_with_payment_response_with_secure_3d
    <<-XML
    <XML>
      <REQUEST>
        <ACTION>INSERT_ORDERWITHPAYMENT</ACTION>
        <META>
          <MERCHANTID>4389</MERCHANTID>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <VERSION>1.0</VERSION>
          <REQUESTIPADDRESS>192.168.41.12</REQUESTIPADDRESS>
        </META>
        <PARAMS>
          <ORDER>
            <ORDERID>1232363800</ORDERID>
            <MERCHANTREFERENCE>1232363800</MERCHANTREFERENCE>
            <AMOUNT>100</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>CA</COUNTRYCODE>
            <LANGUAGECODE>en</LANGUAGECODE>
          </ORDER>
          <PAYMENT>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <AMOUNT>100</AMOUNT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <CREDITCARDNUMBER>4012001011000771</CREDITCARDNUMBER>
            <EXPIRYDATE>0910</EXPIRYDATE>
            <COUNTRYCODE>CA</COUNTRYCODE>
            <LANGUAGECODE>en</LANGUAGECODE>
          </PAYMENT>
        </PARAMS>
        <RESPONSE>
          <RESULT>OK</RESULT>
          <META>
            <REQUESTID>591382</REQUESTID>
            <RESPONSEDATETIME>20090119121642</RESPONSEDATETIME>
          </META>
          <ROW>
            <EFFORTID>1</EFFORTID>
            <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
            <ACSURL>https://dropit.3dsecure.net:9443/PIT/ACS</ACSURL>
            <STATUSDATE>20090119121642</STATUSDATE>
            <STATUSID>50</STATUSID>
            <ADDITIONALREFERENCE>1232363800</ADDITIONALREFERENCE>
            <EXTERNALREFERENCE>1232363800</EXTERNALREFERENCE>
            <ATTEMPTID>1</ATTEMPTID>
            <ORDERID>1232363800</ORDERID>
            <PAREQ>eJxVUdtygkAM/RXHDyCAIuCEncHqVDvV0dqH2hdnu6SFVi4uUPTvu4tY233KSbInJyf4HEui6ZZELYnhksqSf1AviYL+6T119oO9adiePfD6DNfhEx0ZfpMskzxjlqFKCFeo/koR86xiyMVxslixoW+NXBehg5iSXEyZaw7MkW/a5uUhXNKY8ZTYWvKI97YFR2gxirzOKnlmju0hXAHW8sDiqirGAE3TGF+H1BB5iqDzCDch61pHpeI5JREr4iTm9Y7PIvuBjtm9udw8rsJwPmlmAYLuwIhXxJQ037Qsv2dZY2s0Hqol2zzyVAvQiyvZHcBCzwi7ii78TaCyVVImzsx39QJXhHQq8oxUhyL/jRFugu/m2kdRKWvkPH/5tF0ndybeK98J7w2W9SYItLNtg2ZLlC9qvN/SaYCgKaA7GnSXVdG/i/8AtkyoCw==</PAREQ>
            <PROOFXML>&lt;AuthProof&gt;&lt;Time&gt;2009 Jan 19 03:16:42&lt;/Time&gt;&lt;DSUrl&gt;https:198.241.171.150:9443/PIT/DS&lt;/DSUrl&gt;&lt;VEReqProof&gt;&lt;Message id="xfm5_3_0.28236"&gt;&lt;VEReq&gt;&lt;version&gt;1.0.2&lt;/version&gt;&lt;pan&gt;XXXXXXXXXXXX0771&lt;/pan&gt;&lt;Merchant&gt;&lt;acqBIN&gt;491677&lt;/acqBIN&gt;&lt;merID&gt;703069020000000&lt;/merID&gt;&lt;password&gt;scybin26&lt;/password&gt;&lt;/Merchant&gt;&lt;Browser&gt;&lt;accept&gt;null&lt;/accept&gt;&lt;userAgent&gt;null&lt;/userAgent&gt;&lt;/Browser&gt;&lt;/VEReq&gt;&lt;/Message&gt;&lt;/VEReqProof&gt;&lt;VEResProof&gt;&lt;Message id="xfm5_3_0.28236"&gt;&lt;VERes&gt;&lt;version&gt;1.0.2&lt;/version&gt;&lt;CH&gt;&lt;enrolled&gt;Y&lt;/enrolled&gt;&lt;acctID&gt;rHoXj275o5B8ZaYc8b/MuQ==&lt;/acctID&gt;&lt;/CH&gt;&lt;url&gt;https://dropit.3dsecure.net:9443/PIT/ACS&lt;/url&gt;&lt;protocol&gt;ThreeDSecure&lt;/protocol&gt;&lt;/VERes&gt;&lt;/Message&gt;&lt;/VEResProof&gt;&lt;/AuthProof&gt;</PROOFXML>
            <MD>000000438912323638000000100001</MD>
            <MERCHANTID>4389</MERCHANTID>
            <XID>phihauYaEd2JeqnG0MQLNAAHBwE=</XID>
          </ROW>
        </RESPONSE>
      </REQUEST>
    </XML>    
    XML
  end
  
  def successful_do_validate_response
    <<-XML
      <XML> 
       <REQUEST> 
        <ACTION>DO_VALIDATE</ACTION>
        <META> 
          <MERCHANTID>1</MERCHANTID> 
          <IPADDRESS>20.60.98.38</IPADDRESS> 
          <REQUESTIPADDRESS>192.168.203.200:80</REQUESTIPADDRESS>  
          <VERSION>1.0</VERSION> 
        </META>
        <PARAMS> 
          <PAYMENT> 
            <ORDERID>333460</ORDERID> 
            <EFFORTID>1</EFFORTID> 
            <ATTEMPTID>1</ATTEMPTID> 
            <SIGNEDPARES>123432kjvdhasiyfdiasyi23u4h2452g</SIGNEDPARES> 
            <AUTHENTICATIONINDICATOR>1</AUTHENTICATIONINDICATOR> 
          </PAYMENT> 
        </PARAMS>
        <RESPONSE> 
          <RESULT>OK</RESULT>  
            <META> 
              <REQUESTID>1</REQUESTID>  
              <RESPONSEDATETIME>20040629092555</RESPONSEDATETIME>  
            </META> 
            <ROW> 
              <MERCHANTID>1</MERCHANTID> 
              <ORDERID>159152479</ORDERID>  
              <EFFORTID>1</EFFORTID>  
              <ATTEMPTID>1</ATTEMPTID>  
              <STATUSID>800</STATUSID>  
              <STATUSDATE>200406290926555</STATUSDATE>  
              <PAYMENTREFERENCE>0</PAYMENTREFERENCE>  
              <FRAUDRESULT>N</FRAUDRESULT>  
              <FRAUDCODE>0000</FRAUDCODE> 
              <ADDITIONALREFERENCE>00000000010159152479</ADDITIONALREFERENCE>  
              <STATUSDATE>20040629092555</STATUSDATE>  
              <EXTERNALREFERENCE>000000000101591524790000100001</EXTERNALREFERENCE>  
              <AVSRESULT>0</AVSRESULT>  
              <ECI>5</ECI> 
              <CAVV>33240a04aa06dfsafdfas29092fsdaf555</CAVV> 
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
