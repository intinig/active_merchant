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
      
      # Money is passed in cents
      self.money_format = :cents
      
      # Default currency
      self.default_currency = "EUR"
      
      # You can also pass in a :security option that can be :ip_check or :client_auth
      # it is used to check for the correct url to use
      def initialize(options = {})
        requires!(options, :merchant, :ip)
        @options = {:security => :ip_check}.merge(options)
        super
      end  
      
      def authorize(money, creditcard, options = {})
        # post = {}
        # add_invoice(post, options)
        # add_creditcard(post, creditcard)        
        # add_address(post, creditcard)        
        # add_customer_data(post)
        # 
        # commit('authonly', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)
        commit(build_request do |xml|
          xml.request do |request|
            request.action("INSERT_ORDERWITHPAYMENT")
            add_meta(request)
            add_params(request, money, creditcard, options)
          end
        end)
      end                       
        
      def capture(money, authorization, options = {})
      end
    
      private                       
      
      def global_collect_url
        base_url = test? ? "TEST_URL" : "LIVE_URL"
        base_url += @options[:security] == :ip_check ? "_IP_CHECK" : "_CLIENT_AUTH"
        self.class.const_get(base_url)
      end
            
      def commit(request)
        success, message, options = parse(ssl_post(global_collect_url, request))
        Response.new(success, message, {}, options.merge(:test => test?))
      end
      
      def build_request(request = '', &block)
        xml = Builder::XmlMarkup.new(:target => request)
        xml.instruct!
        xml.xml &block
        request
      end
      
      def add_meta(post)
        post.meta do
          post.merchantid(@options[:merchant])
          post.ipaddress(@options[:ip])
          post.version("1.0")
        end
      end
      
      def add_params(post, money, creditcard, options = {})
        post.params do
          add_order(post, money, options)
          add_payment(post, money, creditcard, options)
        end
      end
      
      def add_order(post, money, options = {})
        requires!(options, :order_id, :address)
        requires!(options[:address], :country)
        post.order do
          post.orderid(options[:order_id])
          post.amount(amount(money))
          post.currencycode(options[:currency] || currency(money))
          post.countrycode(options[:address][:country])
          # Forcing to EN
          post.languagecode("EN")
        end
      end
      
      def add_payment(post, money, creditcard, options = {}) 
        
        post.payment do |payment|
          payment.paymentproductid(credit_card_type(creditcard))
          payment.amount(amount(money))
          payment.currencycode(options[:currency] || currency(money))
          payment.creditcardnumber(creditcard.number)
          payment.expirydate(expiration(creditcard))
          payment.countrycode(options[:address][:country])
          payment.languagecode("EN")
        end
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
      
      def message_from(response)
      end
      
      def post_data(action, parameters = {})
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

