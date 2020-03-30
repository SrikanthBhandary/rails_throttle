require 'rack/throttle'
module ThrottlerService
	class Throttler < Rack::Throttle::Limiter
		attr_accessor :client, :ip
		def initialize(app, options = {})
			super
		end
    
    def client_identifier(request)
			if request.env['HTTP_AUTHORIZATION'] || request.params['access_token']
        token = request.env['HTTP_AUTHORIZATION'].present? ? request.env['HTTP_AUTHORIZATION'].split(' ')[-1] : request.params['access_token']          
        @client = token ? User.find_by_api_key(token) : nil
			end
			@ip = request.ip.to_s
		end
    
    def max_per_second
      # @client.try(:limitation).try(:second) || 1
      1
		end
    def max_per_minute
      # @client.try(:limitation).try(:minute) || 20  
      10    
		end
    def max_per_hourly
			@client.try(:limitation).try(:hourly) || 3_600
		end
    def max_per_daily
			@client.try(:limitation).try(:daily) || 86_400
		end
    def max_per_monthly
			@client.try(:limitation).try(:monthly) || 2_592_000
		end
    def allowed?(request)
			client_identifier(request)
      return true if whitelisted?(request)
      puts "******"
    		['second', 'minute', 'hourly', 'daily', 'monthly'].all? { |timeslot| send("#{timeslot}_check".to_sym) }
		end
    def whitelisted?(request)
			@client.try(:email).in? ['YOUR_WHITE_LIST']
		end
    protected

    ['second', 'minute', 'hourly', 'daily', 'monthly'].each do |timeslot|
			define_method("#{timeslot}_check".to_sym) do
        count = cache_get(key = send("#{timeslot}_cache_key".to_sym)).to_i + 1 rescue 1
        allowed = count <= send("max_per_#{timeslot}".to_sym).to_i
        begin
    	    cache_set(key, count)
    	    allowed
        rescue => e          
    	    allowed = true
        end
			end
    end
    
    def second_cache_key
			[@client.try(:id) || @ip, Time.now.strftime('%Y-%m-%dT%H:%M:%S')].join(':')
		end
    def minute_cache_key
			[@client.try(:id) || @ip, Time.now.strftime('%Y-%m-%dT%H:%M')].join(':')
		end
    def hourly_cache_key
			[@client.try(:id) || @ip, Time.now.strftime('%Y-%m-%dT%H')].join(':')
		end
    def daily_cache_key
			[@client.try(:id) || @ip, Time.now.strftime('%Y-%m-%d')].join(':')
		end
    def monthly_cache_key
			[@client.try(:id) || @ip, Time.now.strftime('%Y-%m')].join(':')
		end
  end
end

