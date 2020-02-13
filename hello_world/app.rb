# frozen_string_literal: true

require 'httparty'
require 'json'
require 'roda'

class App < Roda
  plugin :json

  route do |r|
    r.root do
      'Amazon lambda on ruby'
    end

    r.get('hello') do
      res = HTTParty.get('http://checkip.amazonaws.com/')
      {
        message: 'Hello World!',
        code: res.code,
        location: res.body
      }
    end
  end
end

RackHandler = App.freeze.app
SKIP_HEADERS = %w[Content-Type Content-Length rack.hijack].freeze

def lambda_to_rack(event)
  # we trust amazon's input
  headers = event['headers']

  env = {}
  env['REQUEST_METHOD'] = event['httpMethod']

  # it hurts me :(
  env['QUERY_STRING'] = event['queryStringParameters'].to_a.map! { |pair| pair.map(&:to_s).join('=') }.join('&')

  env['SERVER_NAME'] = headers['Host']
  env['REMOTE_HOST'] = headers['Host']
  env['REMOTE_ADDR'] = headers['X-Forwarded-For']
  env['SERVER_PORT'] = headers['X-Forwarded-Port']
  env['rack.url_scheme'] = headers['X-Forwarded-Proto']

  # always HTTP 1.1? :(
  env['HTTP_VERSION'] = 'HTTP/1.1'

  env['REQUEST_PATH'] = event['path']
  env['PATH_INFO'] = event['path']
  env['SCRIPT_NAME'] = ''
  env['REQUEST_URI'] = "#{headers['X-Forwarded-Proto']}://#{headers['Host']}#{event['path']}"
  env['REQUEST_URI'] += "?#{env['QUERY_STRING']}" unless env['QUERY_STRING'].empty?

  headers.each do |k, v|
    next if SKIP_HEADERS.include?(k)

    env["HTTP_#{k.upcase.tr('-', '_')}"] = v
  end

  input = StringIO.new
  input.set_encoding(Encoding::ASCII_8BIT)
  input << event['body']
  input.rewind

  env['rack.input'] = input
  env['rack.errors'] = STDERR
  env['rack.hijack?'] = false
  env['rack.version'] = Rack::VERSION

  env
end

def rack_to_lambda(status, headers, body)
  res = {
    'isBase64Encoded' => false,
    'statusCode' => status,
    'multiValueHeaders' => {}
  }

  headers.each do |k, v|
    next if SKIP_HEADERS.include?(k)

    hv = v.split("\n")
    res['multiValueHeaders'][k] = hv
  end

  if body.respond_to?(:to_path)
    path = body.to_path
    # not support stream. so, good luck.
    res['body'] = File.binread(path)
  else
    res['body'] = body.join
  end

  body.close if body.respond_to?(:close)

  res
end

def lambda_handler(event:, context:)
  env = lambda_to_rack(event)
  status, headers, body = RackHandler.call(env)
  rack_to_lambda(status, headers, body)
end

# def lambda_handler(event:, context:)
  # Sample pure Lambda function

  # Parameters
  # ----------
  # event: Hash, required
  #     API Gateway Lambda Proxy Input Format
  #     Event doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format

  # context: object, required
  #     Lambda Context runtime methods and attributes
  #     Context doc: https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html

  # Returns
  # ------
  # API Gateway Lambda Proxy Output Format: dict
  #     'statusCode' and 'body' are required
  #     # api-gateway-simple-proxy-for-lambda-output-format
  #     Return doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html

#   response = HTTParty.get('http://checkip.amazonaws.com/')
#   {
#     statusCode: response.code,
#     body: {
#       message: 'Hello World!',
#       location: response.body
#     }.to_json
#   }
# rescue HTTParty::Error => e
#   puts e.inspect
#   raise e
# end
