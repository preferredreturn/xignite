module Xignite
  class Service
    extend Xignite::Helpers
    include Xignite::Helpers

    class << self
      attr_accessor :options

      def post(options={})
        response = Curl::Easy.http_post(endpoint, *[].tap do |postbody|
          postbody << Curl::PostField.content('Header_Username', Xignite.configuration.username) if Xignite.configuration.username
          options.each do |key, value|
            postbody << Curl::PostField.content(key, value)
          end
        end)
        new(response)
      end

      def get(options={})
        options = options.merge('Header_Username' => Xignite.configuration.username) if Xignite.configuration.username
        options=options.merge('@xmlns' => "http://www.xignite.com/services/")
        querystring = options.map do |key, value|
          "#{CGI.escape(key.to_s).gsub(/%(5B|5D)/n) { [$1].pack('H*') }}=#{CGI.escape(value)}"
        end.sort * '&'
        request = [endpoint, querystring].reject{|s| s == '' }.join('?')
        puts "Request URL #{request}"
        response = Curl::Easy.http_get(request)
        new(response)
      end

      private

      def endpoint
        names = name.split('::')
        "#{protocol}://#{Xignite.configuration.endpoint}/x#{names[1]}.xml/#{names[2]}"  # use xml instead of asmx
      end

      def protocol
        Xignite.configuration.https ? 'https' : 'http'
      end

      def operations(ops)
        ops.each do |operation, options|
          underscored_name = underscore(operation)
          const_set(operation, Class.new(self))
          const_get(operation).options = options
          class_eval <<-EOF
            class << self
              def #{underscored_name}(options={})
                #{name}::#{operation}.send(Xignite.configuration.request_method, options)
              end
              alias :#{operation} :#{underscored_name}
            end
          EOF
        end
      end
    end

    def initialize(curl_response=nil)
      return if curl_response.nil?
      Crack::XML.parse(curl_response.body_str).each do |klass, data|
        data = weed(data)
        Xignite.const_set(klass, Class.new(Xignite.const_get(data.class.to_s))) unless Xignite.const_defined?(klass)
        instance_variable_set("@#{underscore(klass)}", Xignite.const_get(klass).build(data, self.class.options))
        instance_eval "def #{underscore(klass)} ; @#{underscore(klass)} ; end"
      end
    end

    private

    def weed(data)
      data.reject! { |key, _| key =~ /\Axmlns/ }
      key = data.keys.first
      array = data[key]
      if data.keys.size == 1 && array.class == ::Array
        Xignite.const_set(key, Class.new(Xignite::Hash)) unless Xignite.const_defined?(key)
        array.map do |hash|
          Xignite.const_get(key).build(hash, self.class.options)
        end
      else
        data
      end
    end
  end
end