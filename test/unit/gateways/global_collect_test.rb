require File.dirname(__FILE__) + '/../../test_helper'

class GlobalCollectTest < Test::Unit::TestCase
  def setup
    @gateway = GlobalCollectGateway.new(
      :merchant => '1',
      :ip => '123.123.123.123'
     )

    @credit_card = credit_card
    @amount = 29990
    
    @options = { 
      :order_id => '9998990013',
      :description => 'Store Purchase'
    }
    
    # :customer
    # :invoice
    # :email
    # :currency  
    
  end
  # explorative test, not really necessary
  def test_building_successful_request
    xml = Builder::XmlMarkup.new(:target => (output = '')) 
    xml.instruct!
    xml.xml do
      xml.request do
        xml.action("INSERT_ORDERWITHPAYMENT")
        xml.meta do
          xml.merchantid("1")
          xml.ipaddress("123.123.123.123")
          xml.version("1.0")
        end
        xml.params do
          xml.order do
            xml.orderid("9998990013")
            xml.amount("29990")
            xml.currencycode("EUR")
            xml.countrycode("NL")
            xml.languagecode("NL")
          end
          xml.payment do
            xml.paymentproductid("1")
            xml.amount("2345")
            xml.currencycode("EUR")
            xml.creditcardnumber("4567350000427977")
            xml.expirydate("1206")
            xml.countrycode("NL")
            xml.languagecode("nl")
          end
        end
      end
    end
    assert_equal REXML::Document.new(successful_request).inspect, REXML::Document.new(output).inspect
  end
  
  # explorative test
  def test_decoding_responses
    response = REXML::Document.new(successful_purchase_response)
    assert_equal 'OK', response.root.elements["REQUEST/RESPONSE/RESULT"].text
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_nil response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  def successful_request
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
      </REQUEST>
    </XML>
    XML
  end
  
  def successful_purchase_response
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
          </ROW>
        </RESPONSE>
      </REQUEST>
    </XML>
    XML
  end
  
  def failed_purchase_response
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
  
end
