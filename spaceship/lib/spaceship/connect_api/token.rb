require 'jwt'
require 'openssl'

# extract pem from .p8
# openssl pkcs8 -topk8 -outform PEM -in AuthKey.p8 -out key.pem -nocrypt

# compute public key
# openssl ec -in key.pem -pubout -out public_key.pem -aes256

module Spaceship
  class ConnectAPI
    class Token
      # maximum expiration supported by AppStore (20 minutes)
      MAX_TOKEN_DURATION = 1200

      attr_reader :key_id
      attr_reader :issuer_id
      attr_reader :text
      attr_reader :expiration

      attr_accessor :in_house

      def self.load_json_file(filepath)
        json = JSON.parse(File.read(filepath), { symbolize_names: true })
        self.create(json)
      end

      def self.load_hash(hash)
        key_id = hash[:key_id]
        issuer_id = hash[:issuer_id]
        key = hash[:key]

        key = OpenSSL::PKey::EC.new(key)

        self.new(key_id: key_id, issuer_id: issuer_id, key: key)
      end

      def self.create(key_id: nil, issuer_id: nil, filepath: nil, key: nil, duration: nil, in_house: nil)
        key_id ||= ENV['SPACESHIP_CONNECT_API_KEY_ID']
        issuer_id ||= ENV['SPACESHIP_CONNECT_API_ISSUER_ID']
        filepath ||= ENV['SPACESHIP_CONNECT_API_KEY_FILEPATH']
        duration ||= ENV['SPACESHIP_CONNECT_API_TOKEN_DURATION']

        in_house_env = ENV['SPACESHIP_CONNECT_API_IN_HOUSE']
        in_house ||= !["no", "false", "off", "0"].include?(in_house_env) if in_house_env

        key ||= File.binread(filepath)

        self.new(
          key_id: key_id,
          issuer_id: issuer_id,
          key: OpenSSL::PKey::EC.new(key),
          duration: duration,
          in_house: in_house
        )
      end

      def initialize(key_id: nil, issuer_id: nil, key: nil, duration: nil, in_house: nil)
        @key_id = key_id
        @key = key
        @issuer_id = issuer_id
        @duration = duration
        @in_house = in_house

        @duration ||= MAX_TOKEN_DURATION

        refresh!
      end

      def refresh!
        @expiration = Time.now + @duration.to_i

        header = {
          kid: key_id
        }

        payload = {
          iss: issuer_id,
          exp: @expiration.to_i,
          aud: 'appstoreconnect-v1'
        }

        @text = JWT.encode(payload, @key, 'ES256', header)
      end

      def expired?
        @expiration < Time.now
      end
    end
  end
end
