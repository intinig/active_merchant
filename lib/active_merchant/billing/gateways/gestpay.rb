# require File.dirname(__FILE__) + '/gest_pay/gest_pay'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GestpayGateway < Gateway
      TEST_URL = 'testecomm.sella.it'
      LIVE_URL = 'https://example.com/live'
      VERSION = "S3.1.0"
      
      SEPARATOR = '*P1*'
      REQUEST_PARAMS = [:PAY1_UICCODE, :PAY1_AMOUNT, :PAY1_SHOPTRANSACTIONID, :PAY1_CARDNUMBER, :PAY1_EXPMONTH, :PAY1_EXPYEAR, :PAY1_CHNAME, :PAY1_CVV, :PAY1_BANKTRANSACTIONID]
      RESPONSE_PARAMS = ['PAY1_TRANSACTIONRESULT', 'PAY1_SHOPTRANSACTIONID', 'PAY1_BANKTRANSACTIONID', 'PAY1_UICCODE', 'PAY1_AMOUNT', 'PAY1_AUTHORIZATIONCODE', 'PAY1_ERRORCODE', 'PAY1_ERRORDESCRIPTION', 'PAY1_VBVRISP', 'PAY1_COUNTRY', 'PAY1_VBV', 'PAY1_ALERTCODE', 'PAY1_ALERTDESCRIPTION', 'PAY1_CHEMAIL', 'PAY1_CHNAME']
            
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['IT']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'https://www.sella.it/ecommerce/gestpay/gestpay.jsp'
      
      # The name of the gateway
      self.display_name = 'Gestpay'
      
      def initialize(options = {})
        requires!(options, :shop_login)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        parameters = {}
        add_creditcard(parameters, creditcard)        
        add_transaction_data(parameters, options)
        add_transaction_amount(parameters, money)
        
        parameters[:PAY1_UICCODE] = '242'
        
        commit('auth', parameters)
      end
      
      def renounce(authorization, options = {})
        parameters = {}
        add_transaction_data(parameters, options)
        parameters[:PAY1_BANKTRANSACTIONID] = authorization;
        parameters[:PAY1_UICCODE] = '242'
        commit('renounce', parameters)
      end
      
      def void(authorization, options = {})
        parameters = {}
        add_transaction_data(parameters, options)
        parameters[:PAY1_BANKTRANSACTIONID] = authorization;
        parameters[:PAY1_UICCODE] = '242'
        commit('void', parameters)
      end
      
      def capture(money, authorization, options = {})
        parameters = {}
        add_transaction_amount(parameters, money)
        add_transaction_data(parameters, options)
        parameters[:PAY1_BANKTRANSACTIONID] = authorization;
        parameters[:PAY1_UICCODE] = '242'
        commit('capture', parameters)
      end
      
      def refund(money, authorization, options = {})
        parameters = {}
        add_transaction_amount(parameters, money)
        add_transaction_data(parameters, options)
        parameters[:PAY1_BANKTRANSACTIONID] = authorization;
        parameters[:PAY1_UICCODE] = '242'
        commit('refund', parameters)
      end

      private
      
      def add_transaction_amount(post, amount)
        post[:PAY1_AMOUNT] = amount
      end

      def add_transaction_data(post, options)
        post[:PAY1_SHOPTRANSACTIONID] = options[:transaction_id]
      end
      
      def add_creditcard(post, creditcard)
        post[:PAY1_CARDNUMBER] = creditcard.number
        post[:PAY1_EXPMONTH] = (creditcard.month.to_s.length == 1)? "0#{creditcard.month.to_s}":creditcard.month.to_s
        post[:PAY1_EXPYEAR] = (creditcard.year.to_s.length == 4)? creditcard.year.to_s[2..-1] : creditcard.year.to_s
        post[:PAY1_CHNAME] = creditcard.name
        post[:PAY1_CVV] = creditcard.verification_value if creditcard.verification_value?
      end
      
      def build_request(parameters)
        p = ''
        REQUEST_PARAMS.each {|d|
          if parameters[d]
            p = p + "#{SEPARATOR}#{d}=#{CGI.escape(parameters[d].to_s)}"
          end
        }
        p = p[SEPARATOR.length..-1]
      end
         
      def get_response(data)
        resultcode = data.match('#resultcode#(.*)#\/resultcode#')[1]
        resultdescription = data.match('#resultdescription#(.*)#\/resultdescription#')[1]
        answerstring = data.match('#answerstring#(.*)#\/answerstring#')[1]
        
        response = {}
        answerstring.split('*P1*').each {|r|
          t = r.split('=')
          puts "#{t[0]}\t#{t[1]}"
          response[t[0].to_sym] = t[1]
        }
        
        return response
      end

      def commit(action, parameters)

        case action
        when 'auth'
          page = 'PAGAMS2S.asp'
        when 'capture'
          page = 'settles2s.asp'
        when 'void'
          page = 'deletes2s.asp'
        when 'refund'
          page = 'refunds2s.asp'
        when 'renounce'
          page = 'Renounces2s.asp'
        end

        p = build_request parameters
        a = "a="+CGI.escape(options[:shop_login])+"&b="+p+"&c="+CGI.escape(VERSION)
        url = "https://#{TEST_URL}/Gestpay/#{page}?#{a}"
        # puts "Requesting #{url}"
        
        site = Net::HTTP.new(TEST_URL, 443)
        site.use_ssl = true
        response = get_response(site.get2(url).body)
        
        Response.new((response[:PAY1_TRANSACTIONRESULT] == 'KO') ? false : true, response[:PAY1_ERRORDESCRIPTION], response)
        
      end
    end
  end
end

