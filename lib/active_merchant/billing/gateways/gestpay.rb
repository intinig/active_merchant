module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GestpayGateway < Gateway
      TEST_URL = 'https://testecomm.sella.it/Gestpay/'
      LIVE_URL = 'https://ecomm.sella.it/Gestpay/'
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
      
      self.money_format = :dollars
      
      self.default_currency = "EUR"
      
      # The name of the gateway
      self.display_name = 'Gestpay'
      
      def initialize(options = {})
        requires!(options, :shop_login)
        @options = options
        super
      end  
      
      # CallPagamS2S
      # -- mandatory
      # shop_transaction_id
      # buyer_name
      # -- optional
      # buyer_email
      # language
      # custom_info
      # setcvv
      def authorize(money, creditcard, options = {})
        requires!(options, :shop_transaction_id)
        requires_credit_card_name(creditcard)
        transaction_data = TransactionData.new({:money => money, :credit_card => creditcard}.merge(options))
        resultcode, resultdescription, answerstring = parse(ssl_get(operation_url("PAGAMS2S.asp", transaction_data.to_str)))
        transaction_response = TransactionData.new(answerstring)
        Response.new(transaction_response.success?, resultdescription, transaction_response.attributes, options.merge(:test => test?))
      end
      
      # def renounce(authorization, options = {})
      #   parameters = {}
      #   add_transaction_data(parameters, options)
      #   parameters[:PAY1_BANKTRANSACTIONID] = authorization;
      #   parameters[:PAY1_UICCODE] = '242'
      #   commit('renounce', parameters)
      # end
      
      # CallRenouceS2S
      def void(authorization, options = {})
        parameters = {}
        add_transaction_data(parameters, options)
        parameters[:PAY1_BANKTRANSACTIONID] = authorization;
        parameters[:PAY1_UICCODE] = '242'
        commit('void', parameters)
      end
      
      # CallSettleS2S
      def capture(money, authorization, options = {})
        parameters = {}
        add_transaction_amount(parameters, money)
        add_transaction_data(parameters, options)
        parameters[:PAY1_BANKTRANSACTIONID] = authorization;
        parameters[:PAY1_UICCODE] = '242'
        commit('capture', parameters)
      end
            
      class TransactionData

        # Configuration Data
        attr_accessor :separator, :encrypted_str

        attr_reader :attributes

        REQUEST_MAPPINGS = {
          "PAY1_"            => :custom_info,     
          "PAY1_AMOUNT"      => :amount,
          "PAY1_CARDNUMBER"  => :card_number,
          "PAY1_CHEMAIL"     => :buyer_email,
          "PAY1_CHNAME"      => :buyer_name,
          "PAY1_CVV"         => :cvv,
          "PAY1_EXPMONTH"    => :exp_month,
          "PAY1_EXPYEAR"     => :exp_year,
          "PAY1_IDLANGUAGE"  => :language,
          "PAY1_MIN"         => :min,
          "PAY1_SHOPTRANSACTIONID" => :shop_transaction_id,
          "PAY1_UICCODE"           => :currency
        }

        RESPONSE_MAPPINGS = {
          "PAY1_ALERTCODE" => :alert_code,
          "PAY1_ALERTDESCRIPTION" => :alert_description,
          "PAY1_AUTHORIZATIONCODE" => :authorization_code,
          "PAY1_BANKTRANSACTIONID" => :bank_transaction_id,
          "PAY1_COUNTRY" => :country,
          "PAY1_IDLANGUAGE" => :language,
          "PAY1_TRANSACTIONRESULT" => :transaction_result,
          "PAY1_VBV" => :vbv,
          "PAY1_VBVRISP" => :vbvrisp
        }

        ERROR_MAPPINGS = {
          "PAY1_ERRORCODE" => :error_code,
          "PAY1_ERRORDESCRIPTION" => :error_description
        }

        def initialize(attributes = nil)
          @separator = "*P1*"
          @attributes = {:encrypted_str => nil}

          REQUEST_MAPPINGS.merge(RESPONSE_MAPPINGS).merge(ERROR_MAPPINGS).each_value do |v|
            @attributes = @attributes.merge({v => nil})
          end

          if attributes.respond_to? :has_key?
            money = attributes.delete(:money)
            credit_card = attributes.delete(:credit_card)
            
            unless money.nil?
              attributes[:amount] = (money.cents / 100.00).round(2)
              attributes[:currency] = 242 # only EUR supported!!!
            end
            
            unless credit_card.nil?
              attributes[:card_number] = credit_card.number
              attributes[:exp_month] = sprintf("%.2i", credit_card.month)[-2..-1]
              attributes[:exp_year] = sprintf("%.2i", credit_card.year)[-2..-1]
              attributes[:cvv] = credit_card.verification_value
              attributes[:buyer_name] = credit_card.name
            end
            
            create_from_hash attributes.merge({:card_number => credit_card.number, })
          elsif attributes.respond_to? :to_str
            create_from_string attributes.to_str
          end
        end

        def success?
          @attributes[:transaction_result] == "OK"
        end
        
        def to_str
          string = ""
          REQUEST_MAPPINGS.each do |key, value|
              string += @separator + key + "=" + CGI.escape(@attributes[value].to_s) unless @attributes[value].nil?
            end
          string[@separator.length..-1]
        end

        private

        def create_from_hash attributes
          attributes.each do |key, value|
            if @attributes.has_key? key.to_sym
              @attributes[key.to_sym] = value unless value.nil? || value == ""
            end
          end
        end

        def create_from_string attributes
          @attributes[:custom_info] = ""

          hashed_attributes = attributes.split(@separator).collect do |e|
            key, value = e.split("=")
            [key.to_s, value.to_s]
          end
          
          Hash[*hashed_attributes.flatten].each do |key, value|
            if @attributes.has_key? map_attribute_key(key)
              @attributes[map_attribute_key(key)] = CGI.unescape(value)
            else 
              @attributes[:custom_info] << @separator + CGI.unescape(key) + "=" + CGI.unescape(value)
            end
          end
          @attributes[:custom_info] = nil if @attributes[:custom_info].size == 0
          if @attributes[:error_code] == "0"
            @attributes[:error_code] = nil
            @attributes[:error_description] = nil
          end
        end

        def map_attribute_key(key)
          REQUEST_MAPPINGS.merge(RESPONSE_MAPPINGS).merge(ERROR_MAPPINGS)[key]
        end
      end
      
      protected
      
      def parse(data)
        resultcode = data.match('#resultcode#(.*)#\/resultcode#')[1]
        resultdescription = data.match('#resultdescription#(.*)#\/resultdescription#')[1]
        answerstring = data.match('#answerstring#(.*)#\/answerstring#')[1]
        
        [resultcode, resultdescription, answerstring]
      end
                     
      def get_response(data)
        
        response = {}
        answerstring.split('*P1*').each {|r|
          t = r.split('=')
          # puts "#{t[0]}\t#{t[1]}"
          response[t[0].to_sym] = t[1]
        }
        
        return response
      end

      # def commit(endpoint, )
      #   response = ssl_get()
      #   
      #   # success, message, options = parse(ssl_post(hsbc_url, request))        
      #   # Response.new(success, message, options, options.merge(:test => test?))
      # end
      
      # def commit(action, parameters)
      # 
      #   case action
      #   when 'auth'
      #     page = 'PAGAMS2S.asp'
      #   when 'capture'
      #     page = 'settles2s.asp'
      #   when 'void'
      #     page = 'deletes2s.asp'
      #   when 'refund'
      #     page = 'refunds2s.asp'
      #   when 'renounce'
      #     page = 'Renounces2s.asp'
      #   end
      # 
      #   p = build_request parameters
      #   a = "a="+CGI.escape(options[:shop_login])+"&b="+p+"&c="+CGI.escape(VERSION)
      #   url = "https://#{gestpay_url}/Gestpay/#{page}?#{a}"
      #   
      #   site = Net::HTTP.new(TEST_URL, 443)
      #   site.use_ssl = true
      #   response = get_response(site.get2(url).body)
      #   
      #   Response.new((response[:PAY1_TRANSACTIONRESULT] == 'KO') ? false : true, response[:PAY1_ERRORDESCRIPTION], response)
      #   
      # end
      
      def gestpay_url
        @options[:test] ? TEST_URL : LIVE_URL
      end
      
      def operation_url(op, transaction_data)
        gestpay_url + op + "?a=" + CGI.escape(@options[:shop_login]) + "&b=" + transaction_data.to_str + "&c=" + CGI.escape(VERSION)
      end
      
      def requires_credit_card_name(credit_card)
        raise ArgumentError.new("Missing credit card holder name and surname") if credit_card.name.nil? || credit_card == ""
      end
    end
  end
end

