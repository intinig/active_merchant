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
    
    # :customer
    # :invoice
    # :email
    # :currency  
    
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
    
  # explorative test, not really necessary
  def test_building_successful_request
    block = Proc.new do |xml|
      xml.request do |request|
        request.action("INSERT_ORDERWITHPAYMENT")
        @gateway.send(:add_meta, request)
        @gateway.send(:add_params, request, Money.new(29990, 'EUR'), @credit_card, {:order_id => '9998990013', :address => {:country => 'NL'}})
      end
    end
    @gateway.send(:build_request, (request = ''), &block)
    assert_equal prepare_for_comparison(REXML::Document.new(successful_request).root.to_s), prepare_for_comparison(REXML::Document.new(request).root.to_s)
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
  
  def create_gateway(test = false, security = :ip_check)
    GlobalCollectGateway.new(:merchant => '1', :ip => '123.123.123.123', :test => test, :security => security)
  end
  
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
  
  def prepare_for_comparison(string)
    string.gsub(/\s{2,}/, ' ').gsub(/(\/?)> </, "#{$1}><").downcase
  end
end
