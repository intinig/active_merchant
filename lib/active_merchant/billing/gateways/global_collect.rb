module ActiveMerchant #:nodoc:
  # TOOD: Implement Customer Data
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway      
      TEST_URL_IP_CHECK = 'https://ps.gcsip.nl/wdl/wdl'
      TEST_URL_CLIENT_AUTH = 'https://ca.gcsip.nl/wdl/wdl'
      LIVE_URL_IP_CHECK = 'https://ps.gcsip.com/wdl/wdl'
      LIVE_URL_CLIENT_AUTH = 'https://ca.gcsip.com/wdl/wdl'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      # FIXME Get a list of countries!
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :discover, :american_express, :jcb, :switch, :solo, :dankort, :laser]

      # The homepage URL of the gateway
      self.homepage_url = 'http://globalcollect.nl'

      # The name of the gateway
      self.display_name = 'GlobalCollect'

      # Money is passed in cents
      self.money_format = :cents

      # Default currency
      self.default_currency = "EUR"
      
      # You can also pass in a :security option that can be :ip_check or :client_auth
      # it is used to check for the correct url to use
      # additional options you can use: merchant_reference
      def initialize(options = {})
        requires!(options, :merchant, :ip)
        @options = {:security => :ip_check}.merge(options)
        super
      end  
      
      # INSERT_ORDERWITHPAYMENT
      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)
                
        commit(build_authorize_request(money, creditcard, options))
      end
      
      # authorize, capture
      def purchase(money, creditcard, options = {})
      end                       
      
      # SET_PAYMENT
      # authorization can be anything, it won't be checked against
      def capture(money, authorization, options = {})
        requires!(options, :order_id) 

        success, message, payment_product_id = parse(ssl_post(global_collect_url, build_get_order_status_request(options[:order_id])))
        return Response.new(success, message, {}, {:test => test?}) unless success
        
        commit(build_capture_request(money, options[:order_id], payment_product_id))        
      end
    
      # TODO
      # def void
      # def credit
      
      private                             
      def build_authorize_request(money, creditcard, options)
        build_request do |request|
          request.ACTION("INSERT_ORDERWITHPAYMENT")
          add_meta(request)
          add_authorize_params(request, money, creditcard, options)
        end
      end

      def build_capture_request(money, order_id, payment_product_id)
        build_request do |request|
          request.ACTION("SET_PAYMENT")
          add_meta(request)
          add_capture_params(request, order_id, payment_product_id)
        end
      end
      
      def build_get_order_status_request(order_id)
        build_request do |request|
          request.ACTION("GET_ORDERSTATUS")
          add_meta(request)
          request.PARAMS do |params|
            params.ORDER do |order|
              order.ORDERID(order_id)
            end
          end
        end
      end      
      
      def global_collect_url
        base_url = test? ? "TEST_URL" : "LIVE_URL"
        base_url += @options[:security] == :ip_check ? "_IP_CHECK" : "_CLIENT_AUTH"
        self.class.const_get(base_url)
      end
            
      def commit(request)
        success, message, options = parse(ssl_post(global_collect_url, request))
        Response.new(success, message, {:request_id => options.delete(:request_id)}, options.merge(:test => test?))
      end
      
      def build_request(request = '', &block)
        xml = Builder::XmlMarkup.new(:target => request)
        xml.XML do
          xml.REQUEST &block
        end
        request
      end
      
      def add_meta(post, ipaddress = true)
        post.META do
          post.MERCHANTID(@options[:merchant])
          post.IPADDRESS(@options[:ip]) if ipaddress
          post.VERSION("1.0")
        end
      end
      
      def add_authorize_params(post, money, creditcard, options = {})
        post.PARAMS do
          add_order(post, money, options)
          add_authorize_payment(post, money, creditcard, options)
        end
      end
      
      def add_capture_params(post, order_id, payment_product_id)
        post.PARAMS do
          post.PAYMENT do |payment|
            payment.ORDERID(order_id)
            payment.EFFORTID('1')
            payment.PAYMENTPRODUCTID(payment_product_id)
          end
        end
      end

      def add_order(post, money, options = {})
        requires!(options, :order_id, :address)
        requires!(options[:address], :country)
        post.ORDER do
          post.ORDERID(options[:order_id])
          # Possible Global Collect bug? Requires this Key.
          post.MERCHANTREFERENCE(options[:merchant_reference] || options[:order_id])
          post.AMOUNT(amount(money))
          post.CURRENCYCODE(options[:currency] || currency(money))
          post.COUNTRYCODE(options[:address][:country])
          # Forcing to EN
          post.LANGUAGECODE("en")
        end
      end
      
      def add_authorize_payment(post, money, creditcard, options = {}) 
        post.PAYMENT do |payment|
          payment.PAYMENTPRODUCTID(credit_card_type(creditcard))
          payment.AMOUNT(amount(money))
          payment.CURRENCYCODE(options[:currency] || currency(money))
          payment.CREDITCARDNUMBER(creditcard.number)
          payment.EXPIRYDATE(expiration(creditcard))
          payment.COUNTRYCODE(options[:address][:country])
          payment.LANGUAGECODE("en")
        end
      end
      
      def add_capture_payment(post, money, creditcard, options = {}) 
      end

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)      
      end

      def add_invoice(post, options)
      end
                                       
      def parse(body)
        response = REXML::Document.new(body).root.elements
        success = get_key_from_response(response, "RESULT") == "OK"
        request_id = get_key_from_response(response, "META/REQUESTID")
        message = get_key_from_response(response, "ERROR/MESSAGE")
        authorization = get_key_from_response(response, "ROW/AUTHORISATIONCODE")
        fraud_review = {
          :fraud_result => get_key_from_response(response, "ROW/FRAUDRESULT"),
          :fraud_code => get_key_from_response(response, "ROW/FRAUDCODE"),
          :fraud_neural => get_key_from_response(response, "ROW/FRAUDNEURAL")
        }
        avs_result = get_key_from_response(response, "ROW/AVSRESULT")
        cvv_result = get_key_from_response(response, "ROW/CVVRESULT")
        [success, message, {:authorization => authorization, :fraud_review => fraud_review, :avs_result => avs_result, :cvv_result => cvv_result, :request_id => request_id}]
      end     
      
      def parse_order(body)
        response = REXML::Document.new(body).root.elements
        success = get_key_from_response(response, "RESULT") == "OK"
        message = get_key_from_response(response, "ERROR/MESSAGE")
        payment_product_id = get_key_from_response(response, "ROW/PAYMENTPRODUCTID")
        [success, message, payment_product_id]
      end
      
      def get_key_from_response(response, path)
        get_key_from_path_with_root(response, "REQUEST/RESPONSE", path)
      end
      
      def get_key_from_path_with_root(response, root, path)
        (result = response["#{root.gsub(%r(/$),'')}/#{path.gsub(%r(^/), '')}"]).nil? ? result : result.text
      end
            
      def credit_card_type(creditcard)
        {:visa => 1, :master => 3, :discover => 128, :american_express => 2, :jcb => 125, :switch => 117, :solo => 118,  :dankort => 123, :laser => 124}[creditcard.type]
      end
      
      # Should run against the test servers or not?
      def test?
        if @options[:test].nil?
          super
        else
          @options[:test]
        end
      end
      
      def expiration(creditcard)
        month = creditcard.month < 10 ? "0#{creditcard.month}" : "#{creditcard.month}"
        year = "#{creditcard.year}"[2,2]
        month + year
      end
    end
  end
end

