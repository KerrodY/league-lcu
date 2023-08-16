require 'open3'
require 'base64'
require 'json'
require 'net/http'
require 'openssl'

@encoded_token = nil
@base_url = nil
@headers = nil

def extract_riotclient_values(output)
  riotclient_auth_token = output.match(/--remoting-auth-token=([^\s"]+)/)&.captures&.first
  riotclient_app_port = output.match(/--app-port=([^\s"]+)/)&.captures&.first

  [riotclient_auth_token, riotclient_app_port]
end

def authenticate!
  process_name = 'LeagueClientUx.exe'
  case RbConfig::CONFIG['host_os']
  when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    command = "wmic PROCESS WHERE name='#{process_name}' GET commandline"
  when /linux|darwin/
    command = "ps aux | grep #{process_name}"
  else
    raise "Unsupported OS"
  end

  stdout, stderr, status = Open3.capture3(command)

  if status.success?
    auth_token, app_port = extract_riotclient_values(stdout)
  else
    puts "Error: "
    puts stderr
  end

  @encoded_token = "Basic #{Base64.strict_encode64("riot:#{auth_token}")}"
  @base_url = "https://127.0.0.1:#{app_port}"
  @headers = {
  'accept' => 'application/json',
  'Authorization' => @encoded_token
  }

end

def perform_get_request(url)
  uri = URI(@base_url + url)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Disable certificate verification

  request = Net::HTTP::Get.new(uri.path)
  @headers.each { |key, value| request[key] = value }

  response = http.request(request)

  JSON.parse(response.body)
  
rescue StandardError => e
  puts "Error: #{e.message}"
end

def get_data(url)
  response = perform_get_request(url)
  response.each { |i| puts i}
end

authenticate!

get_data('/lol-rewards/v1/grants')