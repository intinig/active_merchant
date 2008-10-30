module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GlobalCollectGateway < Gateway
      # NOTE: The AUTHORISATIONCODE has to be configured or won't be present in the response
      
      TEST_URL_IP_CHECK = 'https://ps.gcsip.nl/wdl/wdl'
      TEST_URL_CLIENT_AUTH = 'https://ca.gcsip.nl/wdl/wdl'
      LIVE_URL_IP_CHECK = 'https://ps.gcsip.com/wdl/wdl'
      LIVE_URL_CLIENT_AUTH = 'https://ca.gcsip.com/wdl/wdl'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :discover, :american_express, :jcb, :switch, :solo, :dankort, :laser]
      # The homepage URL of the gateway
      self.homepage_url = 'http://globalcollect.nl'
      
      # The name of the gateway
      self.display_name = 'GlobalCollect'
      
      def initialize(options = {})
        requires!(options, :merchant, :ip)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('authonly', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        commit build_request do |xml|
          xml.request do |request|
            request.action("INSERT_ORDERWITHPAYMENT")
            add_meta(request)
            add_params(request, money, creditcard)
          end
        end
      end                       
        
      def capture(money, authorization, options = {})
      end
    
      private                       
            
      def build_request(request = '', &block)
        xml = Builder::XmlMarkup.new(:target => request)
        xml.instruct!
        xml.xml &block
        request
      end
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)      
      end

      def add_invoice(post, options)
      end
         
      def add_payment(post, creditcard) 
        post.payment do |payment|
          # FIXME again
          payment.paymentproductid("1")
          payment.amount("2345")
          payment.currencycode("EUR")
          add_creditcard(payment, creditcard)
          payment.countrycode("NL")
          payment.languagecode("nl")
        end
      end
      def add_creditcard(post, creditcard)      
        post.creditcardnumber(creditcard.number)
        post.expirydate("#{creditcard.month}#{creditcard.year}")
      end
      
      def add_meta(post)
        post.meta do
          post.merchantid(@options[:merchant])
          post.ipaddress(@options[:ip])
          post.version("1.0")
        end
      end
      
      def add_params(post, money, creditcard)
        post.params do
          add_order(post, money)
          add_payment(post, creditcard)
        end
      end
      
      def add_order(post, money)
        post.order do
          post.orderid(options[:order_id])
          post.amount(money)
          # FIXME estrai da qui 
          post.currencycode("EUR")
          # FIXME come li determino?
          post.countrycode("NL")
          post.languagecode("NL")
        end
      end
      
      def parse(body)
        response = REXML::Document.new(body).root.elements
        success = get_key_from_response(response, "RESULT") == "OK"
        message = get_key_from_response(response, "ERROR/MESSAGE")
        authorization = get_key_from_response(response, "ROW/AUTHORISATIONCODE")
        fraud_review = {
          :fraud_result => get_key_from_response(response, "ROW/FRAUDRESULT"),
          :fraud_code => get_key_from_response(response, "ROW/FRAUDCODE"),
          :fraud_neural => get_key_from_response(response, "ROW/FRAUDNEURAL")
        }
        avs_result = get_key_from_response(response, "ROW/AVSRESULT")
        cvv_result = get_key_from_response(response, "ROW/CVVRESULT")
        [success, message, {:authorization => authorization, :fraud_review => fraud_review, :avs_result => avs_result, :cvv_result => cvv_result}]
      end     
      
      def get_key_from_response(response, path)
        get_key_from_path_with_root(response, "REQUEST/RESPONSE", path)
      end
      
      def get_key_from_path_with_root(response, root, path)
        (result = response["#{root.gsub(%r(/$),'')}/#{path.gsub(%r(^/), '')}"]).nil? ? result : result.text
      end
      
      def commit(request)
        success, message, options = parse(ssl_post(test? ? TEST_URL_IP_CHECK : LIVE_URL_IP_CHECK, request))
        Response.new(success, message, {}, options.merge(:test => test?))
      end

      def message_from(response)
      end
      
      def post_data(action, parameters = {})
      end
      
      # Should run against the test servers or not?
      def test?
        @options[:test] || super
      end
      
    end
  end
end

