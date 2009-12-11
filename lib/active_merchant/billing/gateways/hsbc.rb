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
        requires!(options, :order_id)        
        response = commit(build_purchase_request(money, creditcard, options))        
      end                       
    
      # postauth
      def capture(money, authorization, options = {})
        requires!(options, :order_id)
        response = commit(build_capture_request(options))
      end
    
      # void
      def void(money, authorization, options = {})
        requires!(options, :order_id)
        response = commit(build_void_request(options))
      end
      
      # credit
      def refund(money, creditcard, options = {})
        response = commit(build_refund_request(money, creditcard, options))
      end
      private                       
            
      def parse(body)  
        #todo vbv authorization, look for PayerAuthenticationCode
            
        r = REXML::Document.new(body)
        response = r.root.elements
        # changed by LUCAT
        success = get_key_from_response(response, "EngineDocList.EngineDoc.OrderFormDoc.Transaction.CardProcResp.ProcReturnCode") == "00"
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
          add_auth_order_form_doc(request, money, creditcard, options)
        end # enginedoc
      end
      
      def build_purchase_request(money, creditcard, options)
        build_request do |request|
          add_auth_order_form_doc(request, money, creditcard, options, "Auth")
        end
      end
      
      def build_capture_request(options)
        build_request do |request|
          request.OrderFormDoc do |orderformdoc|
            orderformdoc.Id(options[:order_id])
            orderformdoc.Mode(@options[:mode])
            orderformdoc.Transaction do |transaction|
              transaction.Type("PostAuth")
            end
          end # orderformdoc
        end
      end

      def build_void_request(options)
        build_request do |request|
          request.OrderFormDoc do |orderformdoc|
            orderformdoc.Id(options[:order_id])
            orderformdoc.Mode(@options[:mode])
            orderformdoc.Transaction do |transaction|
              transaction.Type("Void")
            end
          end # orderformdoc
        end
      end
      
      def build_refund_request(money, creditcard, options)
        build_request do |request|
          request.OrderFormDoc do |orderformdoc|
            orderformdoc.Mode(@options[:mode])
            add_consumer(orderformdoc, creditcard)
            orderformdoc.Transaction do |transaction|
              transaction.Type("Credit")
              transaction.CurrentTotals do |currenttotals|
                currenttotals.Totals do |totals|
                  totals.Total(money.cents, "DataType" => "Money", "Currency" => CURRENCY_CODES[money.currency])
                end # totals
              end # currenttotals
            end
          end # orderformdoc
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
      def add_auth_order_form_doc(request, money, creditcard, options, type = "PreAuth")
        request.OrderFormDoc do |orderformdoc|
          orderformdoc.Id(options[:order_id])
          orderformdoc.Mode(@options[:mode])
          add_consumer(orderformdoc, creditcard)
          add_transaction(orderformdoc, money, type, options)
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
      def add_transaction(orderformdoc, money, type = "PreAuth", options = {})
        orderformdoc.Transaction do |transaction|
          transaction.Type(type)
          transaction.CurrentTotals do |currenttotals|
            currenttotals.Totals do |totals|
              totals.Total(money.cents, "DataType" => "Money", "Currency" => CURRENCY_CODES[money.currency])
            end # totals
          end # currenttotals
          transaction.PayerSecurityLevel(options[:payer_security_level]) if options[:payer_security_level]  # changed by LUCAT
          transaction.PayerAuthenticationCode(options[:payer_authentication_code]) if options[:payer_authentication_code]
          transaction.PayerTxnId(options[:payer_txn_id]) if options[:payer_txn_id]                          # changed by LUCAT
          transaction.CardholderPresentCode(options[:cardholder_present_code]) if options[:cardholder_present_code] # changed by LUCAT
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

