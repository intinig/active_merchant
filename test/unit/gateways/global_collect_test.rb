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
  
  # a symbol can't start with a number. so we use secure_3d instead of 3d_secure
  def test_authorize_should_build_correct_do_checkenrollment_request_if_secure_3d_if_true
    # I use an other gateway because the secure_3d option is used just here
    gateway = GlobalCollectGateway.new( :merchant => '1', :ip => '123.123.123.123', :test => true, :secure_3d => true)
    request = gateway.send(:build_do_checkenrollment_request, Money.new(29990, 'EUR'), @credit_card, {:order_id => '9998990013', :address => {:country => 'NL'}})
    assert_equal_xml successful_do_checkenrollment_request, request
  end
  
  def test_should_parse_acs_url_on_do_checkenrollment_response
    success, message, options = @gateway.send(:parse, successful_do_checkenrollment_response)
    assert_not_nil options[:acs_url]
  end
  
  def test_should_parse_pareq_on_do_checkenrollment_response
    success, message, options = @gateway.send(:parse, successful_do_checkenrollment_response)
    assert_not_nil options[:pareq]
  end
  
  def test_should_parse_md_on_do_checkenrollment_response
    success, message, options = @gateway.send(:parse, successful_do_checkenrollment_response)
    assert_not_nil options[:md]
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
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>NL</COUNTRYCODE>
            <ORDERID>9998990013</ORDERID>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <EXPIRYDATE>1206</EXPIRYDATE>
            <CREDITCARDNUMBER>4567350000427977</CREDITCARDNUMBER>
            <CURRENCYCODE>EUR</CURRENCYCODE>            
            <AMOUNT>29990</AMOUNT>            
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

  def successful_do_checkenrollment_response
    <<-XML
    <XML>
      <REQUEST>
        <ACTION>DO_CHECKENROLLMENT</ACTION>
        <META>
          <MERCHANTID>4389</MERCHANTID>
          <IPADDRESS>123.123.123.123</IPADDRESS>
          <VERSION>1.0</VERSION>
          <REQUESTIPADDRESS>192.168.41.12</REQUESTIPADDRESS>
        </META>
        <PARAMS>
          <PAYMENT>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <COUNTRYCODE>CA</COUNTRYCODE>
            <ORDERID>1232029274</ORDERID>
            <PAYMENTPRODUCTID>1</PAYMENTPRODUCTID>
            <EXPIRYDATE>0910</EXPIRYDATE>
            <CREDITCARDNUMBER>4012001011000771</CREDITCARDNUMBER>
            <CURRENCYCODE>EUR</CURRENCYCODE>
            <AMOUNT>100</AMOUNT>
            <AUTHENTICATIONINDICATOR>1</AUTHENTICATIONINDICATOR>
          </PAYMENT>
        </PARAMS>
        <RESPONSE>
          <RESULT>OK</RESULT>
          <META>
            <REQUESTID>253185</REQUESTID>
            <RESPONSEDATETIME>20090115152119</RESPONSEDATETIME>
          </META>
          <ROW>
            <EFFORTID>1</EFFORTID>
            <PAYMENTREFERENCE>0</PAYMENTREFERENCE>
            <ACSURL>https://dropit.3dsecure.net:9443/PIT/ACS</ACSURL>
            <STATUSDATE>20090115152119</STATUSDATE>
            <STATUSID>50</STATUSID>
            <ADDITIONALREFERENCE>00000043891232029274</ADDITIONALREFERENCE>
            <EXTERNALREFERENCE>000000438912320292740000100001</EXTERNALREFERENCE>
            <ATTEMPTID>1</ATTEMPTID>
            <ORDERID>1232029274</ORDERID>
            <PAREQ>eJxVUe1ygjAQfBXHByABRcQ5MoPVUTtqae1M+8/JhGullQABCr59E8R+5Nft3WVvbw+eTwpxcUBRK2Sww7Lk7zhI4mDYvqXucXSkluM5Hh0yiMInLBh8oSqTTDLb0iUgN6j/KnHismLARTHf7NnYtyeeB6SHkKLaLJhHR3TiU4deH5BrGiRPkUWKx3xwyDmQDoPIalmpC3OdKZAbgFqd2amq8hkhTdNYn+fUElkKxOSB/AqJahOVmqdNYtbW8WL6sIuWsXOPhVzR3eN2H4brebMMgJgOiHmFTEvzqW27A3s8c+yZ7QPp8sBTI8AsrmX3AHIzI+wrpvA3AdpWhVJcmO+ZBW4IsM0zibpDO/gTA/kVfLc2PopKW6PW2euH47mZG67ktnmpRJG0YRAYZ7sGw5ZoX/R4v6MzAIihIP3RSH9ZHf27+DdX8Kgy</PAREQ>
            <PROOFXML>&lt;AuthProof&gt;&lt;Time&gt;2009 Jan 15 06:21:19&lt;/Time&gt;&lt;DSUrl&gt;https:198.241.171.150:9443/PIT/DS&lt;/DSUrl&gt;&lt;VEReqProof&gt;&lt;Message id="xfm5_3_0.27268"&gt;&lt;VEReq&gt;&lt;version&gt;1.0.2&lt;/version&gt;&lt;pan&gt;XXXXXXXXXXXX0771&lt;/pan&gt;&lt;Merchant&gt;&lt;acqBIN&gt;491677&lt;/acqBIN&gt;&lt;merID&gt;703069020000000&lt;/merID&gt;&lt;password&gt;scybin26&lt;/password&gt;&lt;/Merchant&gt;&lt;Browser&gt;&lt;accept&gt;null&lt;/accept&gt;&lt;userAgent&gt;null&lt;/userAgent&gt;&lt;/Browser&gt;&lt;/VEReq&gt;&lt;/Message&gt;&lt;/VEReqProof&gt;&lt;VEResProof&gt;&lt;Message id="xfm5_3_0.27268"&gt;&lt;VERes&gt;&lt;version&gt;1.0.2&lt;/version&gt;&lt;CH&gt;&lt;enrolled&gt;Y&lt;/enrolled&gt;&lt;acctID&gt;rHoXj275o5AGnLwWtcqixA==&lt;/acctID&gt;&lt;/CH&gt;&lt;url&gt;https://dropit.3dsecure.net:9443/PIT/ACS&lt;/url&gt;&lt;protocol&gt;ThreeDSecure&lt;/protocol&gt;&lt;/VERes&gt;&lt;/Message&gt;&lt;/VEResProof&gt;&lt;/AuthProof&gt;</PROOFXML>
            <MD>000000438912320292740000100001</MD>
            <MERCHANTID>4389</MERCHANTID>
            <XID>xudD8OMPEd2JeqnG0MQLNAAHBwE=</XID>
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
