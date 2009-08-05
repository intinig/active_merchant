require File.dirname(__FILE__) + "/hsbc/hsbc_builder"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HsbcGateway < Gateway
      TEST_URL = 'https://www.uat.apixml.netq.hsbc.com'
      LIVE_URL = 'https://www.secure-epayments.apixml.hsbc.com'
      
      CURRENCY_CODES = {
        "EUR"  => "978",
        "GBP"  => "826",
        "USD"  => "840",
      }
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['UK']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://hsbc.com'
      
      # The name of the gateway
      self.display_name = 'HSBC'
      
      # Money is passed in cents
      self.money_format = :cents

      # Default currency
      self.default_currency = "GBP"
      
      def initialize(options = {})
        requires!(options, :client_id, :name, :password)
        options[:pipeline] ||= "Payment"
        options[:locale] ||= "826" # defaults to UK
        raise "Cannot use mode \"P\" in test mode" if options[:test] && (options[:mode] == "P")
        options[:mode] ||= options[:test] ? "Y" : "P"
        @options = options
        super
      end  
      
      # preauth
      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)        
        response = commit(build_authorize_request(money, creditcard, options))        
      end
      
      # auth
      def purchase(money, creditcard, options = {})
      end                       
    
      # postauth
      def capture(money, authorization, options = {})
        requires!(options, :order_id)
        response = commit(build_capture_request(money, options))
      end
    
      # void
      def void(moeny, authorization, options = {})
      end
      
      # credit
      def refund(money, authorization, options = {})
      end
      private                       
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)      
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(post, creditcard)      
      end
      
      def parse(body)  
        #todo vbv authorization, look for PayerAuthenticationCode
            
        r = REXML::Document.new(body)
        response = r.root.elements
        success = get_key_from_response(response, "EngineDocList.EngineDoc.OrderFormDoc.Transaction.CardProcResp.Status") == "1"
        document_id = get_key_from_response(response, "EngineDocList.EngineDoc.DocumentId")
        message = get_message_from_response(response)        
        fraud_info = {
          :fraud_result => get_key_from_response(response, "EngineDocList.EngineDoc.OrderFormDoc.FraudInfo.FraudResult"),
          :fraud_code => get_key_from_response(response, "EngineDocList.EngineDoc.OrderFormDoc.FraudInfo.FraudResultCode"),
          :order_score => get_key_from_response(response, "EngineDocList.EngineDoc.OrderFormDoc.FraudInfo.OrderScore")
        }
        auth_code = get_key_from_response(response, "EngineDocList.EngineDoc.OrderFormDoc.Transaction.AuthCode")
        [success, message, 
          { 
            :auth_code => auth_code,
            :fraud_info => fraud_info, 
            :document_id => document_id
          }
        ]
      end     
      
      def commit(request)
        success, message, options = parse(ssl_post(hsbc_url, request))        
        Response.new(success, message, options, options.merge(:test => test?))
      end

      def message_from(response)
      end
      
      def post_data(action, parameters = {})
      end
      
      protected
      
      def build_request(request = '', &block)
        xml = HsbcBuilder.new(:target => request)
        xml.instruct!
        xml.EngineDocList do
          xml.DocVersion("1.0")
          xml.EngineDoc do |enginedoc|
            enginedoc.ContentType("OrderFormDoc")
            add_user_data(enginedoc)
            enginedoc.Instructions do |instructions|
              instructions.Pipeline(@options[:pipeline])
            end
            yield enginedoc
          end 
        end
        request
      end

      def build_authorize_request(money, creditcard, options)
        build_request do |request|
          add_preauth_order_form_doc(request, money, creditcard, options)
        end # enginedoc
      end
      
      def build_capture_request(money, options)
        build_request do |request|
          add_postauth_order_form_doc(request, options)
        end
      end
      
      # implemented
      def add_user_data(request)
        request.User do |user|
          user.ClientId(@options[:client_id], "DataType" => "S32")
          user.Name(@options[:name])
          user.Password(@options[:password])
        end
      end
      
      # implemented
      def add_preauth_order_form_doc(request, money, creditcard, options)
        request.OrderFormDoc do |orderformdoc|
          orderformdoc.Id(options[:order_id])
          orderformdoc.Mode(@options[:mode])
          add_consumer(orderformdoc, creditcard)
          add_transaction(orderformdoc, money)
        end # orderformdoc
      end
      
      def add_postauth_order_form_doc(request, options)
        request.OrderFormDoc do |orderformdoc|
          orderformdoc.Id(options[:order_id])
          orderformdoc.Mode(@options[:mode])
          orderformdoc.Transaction do |transaction|
            transaction.Type("PostAuth")
          end
        end # orderformdoc
      end
      
      # implemented
      def add_consumer(orderformdoc, creditcard)
        orderformdoc.Consumer do |consumer|
          consumer.PaymentMech do |paymentmech|
            paymentmech.Type("CreditCard")
            paymentmech.CreditCard do |credit_card|
              credit_card.Number(creditcard.number)
              credit_card.Expires(expiration_date(creditcard), "DataType" => "ExpirationDate", "Locale" => @options[:locale])
            end # creditcard
          end # paymentmech
        end # consumer
      end
      
      # implemented
      def add_transaction(orderformdoc, money)
        orderformdoc.Transaction do |transaction|
          transaction.Type("PreAuth")
          transaction.CurrentTotals do |currenttotals|
            currenttotals.Totals do |totals|
              totals.Total(money.cents, "DataType" => "Money", "Currency" => CURRENCY_CODES[money.currency])
            end # totals
          end # currenttotals
        end # transaction
      end
      
      def expiration_date(creditcard)
        "#{format(creditcard.month, :two_digits)}/#{format(creditcard.year, :two_digits)}"
      end
      
      def hsbc_url
        @options[:test] ? TEST_URL : LIVE_URL
      end
      
      def get_key_from_response(response, path)
        xpath = path.split(".").join("/")
        key = response["/#{xpath}"]
        key.nil? ? nil : key.text
      end
      
      def get_message_from_response(response)
        messages = []
        xpath = "/EngineDocList/EngineDoc/MessageList/Message"
        response.each(xpath) do |msg|
          messages << msg.elements["Text"].text
        end
        messages.join(", ")
      end
    end
  end
end

