require "jwt"
require "rack/test"
require "spec_helper"


RSpec.describe ButsOiliwt::App do
  module RSpecMixin
    include Rack::Test::Methods

    def app
      described_class
    end
  end

  before do
    RSpec.configure do |c|
      c.include RSpecMixin
    end
  end

  describe "requests" do
    describe "GET /sdk/js/chat/v3.3/twilio-chat.min.js" do
      it "returns status 200" do
        get "/sdk/js/chat/v3.3/twilio-chat.min.js"

        expect(last_response.status).to eq(200)
      end

      it "returns content type javascript" do
        get "/sdk/js/chat/v3.3/twilio-chat.min.js"

        expect(last_response.content_type).to eq("text/javascript;charset=utf-8")
      end

      it "sets host to ButsOiliwt.twilio_host" do
        fake_host = "localhost:1234"
        allow(ButsOiliwt).to receive(:twilio_host).and_return(fake_host)
        get "/sdk/js/chat/v3.3/twilio-chat.min.js"

        expect(last_response.body).to include("host: \"#{fake_host}\"")
      end
    end

    describe "GET /js_api/channels/:channel_name" do
      it "returns status 200" do
        channel_name = "new_channel"
        channel_info = {
          "grants": {
            "identity": "visitor_1",
            "chat": {
              "service_sid": "sid",
            },
          },
        }
        token = JWT.encode(channel_info, nil, "none")
        params = {
          token: token,
        }

        get "/js_api/channels/#{channel_name}", params

        expect(last_response.status).to eq(200)
      end

      it "creates a channel" do
        channel_name = "new_channel"
        identity = "identity"
        service_sid = "123"
        channel_info = {
          "grants": {
            "identity": identity,
            "chat": {
              "service_sid": service_sid,
            },
          },
        }
        token = JWT.encode(channel_info, nil, "none")
        params = {
          token: token,
        }

        get "/js_api/channels/#{channel_name}", params

        channel_record = ButsOiliwt::DB.read("channel_#{channel_name}")
        expect(channel_record[:name]).to eq(channel_name)
        expect(channel_record[:customer_id]).to eq(identity)
        expect(channel_record[:chat_id]).to eq(service_sid)
      end

      it "creates messages array for channel" do
        channel_name = "new_channel"
        channel_info = {
          "grants": {
            "identity": "visitor_1",
            "chat": {
              "service_sid": "sid",
            },
          },
        }
        token = JWT.encode(channel_info, nil, "none")
        params = {
          token: token,
        }

        get "/js_api/channels/#{channel_name}", params

        db_key = "channel_#{channel_name}_messages"
        messages = ButsOiliwt::DB.read(db_key)

        expect(messages).to eq([])
      end
    end

    describe "GET /js_api/channels/:channel/messages" do
      it "returns status 200" do
        channel_name = "channel"
        db_key = "channel_#{channel_name}_messages"
        ButsOiliwt::DB.write(db_key, ["message"])

        get "/js_api/channels/#{channel_name}/messages"

        expect(last_response.status).to eq(200)
      end

      it "returns last message" do
        channel_name = "channel"
        messages = ["fisrt", "second", "last"]
        db_key = "channel_#{channel_name}_messages"
        ButsOiliwt::DB.write(db_key, messages)

        get "/js_api/channels/#{channel_name}/messages"

        response = JSON.parse(last_response.body)

        expect(response["message"]).to eq(messages.last)
      end
    end

    describe "POST /js_api/channels/:channel/messages" do
      it "returns status 200" do
        channel_name = "chanel"
        request_body = {
          message: "hello",
        }.to_json
        headers = { "CONTENT_TYPE" => "application/json" }
        db_key = "channel_#{channel_name}"
        ButsOiliwt::DB.write(db_key, {})

        stub_dialog_resolver

        post "/js_api/channels/#{channel_name}/messages", request_body, headers

        expect(last_response.status).to eq(200)
      end

      it "calls DialogResolver" do
        channel_name = "chanel"
        request_body = {
          message: "hello",
        }.to_json
        headers = { "CONTENT_TYPE" => "application/json" }
        db_key = "channel_#{channel_name}"
        ButsOiliwt::DB.write(db_key, {})

        dialog_resolver = stub_dialog_resolver

        post "/js_api/channels/#{channel_name}/messages", request_body, headers

        expect(ButsOiliwt::DialogResolver).
          to have_received(:new).
          with(channel_name, anything)
        expect(dialog_resolver).to have_received(:call)
      end

      it "saves message with metadata to db" do
        channel_name = "chanel"
        message = "message"
        request_body = {
          message: message,
        }.to_json
        headers = { "CONTENT_TYPE" => "application/json" }
        channel_db_key = "channel_#{channel_name}"
        customer_id = "123"
        channel_data = {
          customer_id: customer_id,
        }
        message_db_key = "channel_#{channel_name}_messages"
        ButsOiliwt::DB.write(channel_db_key, channel_data)
        ButsOiliwt::DB.write(message_db_key, [])

        stub_dialog_resolver

        post "/js_api/channels/#{channel_name}/messages", request_body, headers

        last_message = ButsOiliwt::DB.read(message_db_key).last

        expect(last_message[:body]).to eq(message)
        expect(last_message[:author]).to eq(customer_id)
      end

      def stub_dialog_resolver
        dialog_resolver = instance_double(ButsOiliwt::DialogResolver)
        allow(ButsOiliwt::DialogResolver).
          to receive(:new).
          and_return(dialog_resolver)
        allow(dialog_resolver).to receive(:call)
        dialog_resolver
      end
    end

    describe "POST autopilot/update" do
      it "returns 200" do
        headers = { "CONTENT_TYPE" => "application/json" }

        post "autopilot/update", { schema: {}.to_json }.to_json, headers

        expect(last_response.status).to eq(200)
      end

      it "writes schema to DB" do
        schema = { "key_1" => "value" }
        headers = { "CONTENT_TYPE" => "application/json" }

        post "autopilot/update", { schema: schema.to_json }.to_json, headers

        db_schema = ButsOiliwt::DB.read("schema")

        expect(db_schema).to eq(schema)
      end
    end

    describe "GET /v2/Services/:assistant_id/Channels/:visitor_id" do
      it "returns status 200" do
        get "/v2/Services/123/Channels/123"

        expect(last_response.status).to eq(200)
      end

      it "writes metadata to db" do
        assistant_id = 123
        visitor_id = 456

        get "/v2/Services/#{assistant_id}/Channels/#{visitor_id}"

        expect(ButsOiliwt::DB.read("assistant_id")).to eq(assistant_id.to_s)
        expect(ButsOiliwt::DB.read("customer_id")).to eq(visitor_id.to_s)
      end

      it "returns fake json" do
        expected_response = { "unique_name" => "hello", "sid" => "hello_sid" }

        get "/v2/Services/123/Channels/123"

        response = JSON.parse(last_response.body)

        expect(response).to eq(expected_response)
      end
    end

    describe "POST /v1/Assistants" do
      it "returns 200" do
        post "/v1/Assistants"

        expect(last_response.status).to eq(200)
      end

      it "writes assistant data to db" do
        friendly_name = "X AE A-12"
        md5 = "123"
        imei = "456"
        sid = "UA" + md5
        unique_name = sid + "-" + imei
        params = {
          "FriendlyName": friendly_name,
        }

        allow(Faker::Code).to receive(:imei).and_return(imei)
        allow(Faker::Crypto).to receive(:md5).and_return(md5)

        post "/v1/Assistants", params

        chatbot = ButsOiliwt::DB.read("chatbot")

        expect(chatbot[:friendly_name]).to eq(friendly_name)
        expect(chatbot[:assistant_sid]).to eq(sid)
        expect(chatbot[:unique_name]).to eq(unique_name)
      end

      it "returns assistant_sid and unique name" do
        friendly_name = "X AE A-12"
        md5 = "123"
        imei = "456"
        sid = "UA" + md5
        unique_name = sid + "-" + imei
        params = {
          "FriendlyName": friendly_name,
        }

        allow(Faker::Code).to receive(:imei).and_return(imei)
        allow(Faker::Crypto).to receive(:md5).and_return(md5)

        post "/v1/Assistants", params

        response = JSON.parse(last_response.body)

        expect(response["sid"]).to eq(sid)
        expect(response["unique_name"]).to eq(unique_name)
      end
    end

    describe "POST /:api_v/Accounts/:account_id/IncomingPhoneNumbers.json" do
      it "returns status 200" do
        ButsOiliwt::DB.write("chatbot", {})

        post "/v2/Accounts/123/IncomingPhoneNumbers.json"

        expect(last_response.status).to eq(200)
      end

      it "writes phone number data to db" do
        md5 = "123"
        phone_number = "4567"
        phone_number_sid = "PN" + md5

        ButsOiliwt::DB.write("chatbot", {})

        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        allow(Faker::PhoneNumber).
          to receive(:cell_phone).
          and_return(phone_number)

        post "/v2/Accounts/123/IncomingPhoneNumbers.json"

        chatbot = ButsOiliwt::DB.read("chatbot")

        expect(chatbot[:phone_number]).to eq(phone_number)
        expect(chatbot[:phone_number_sid]).to eq(phone_number_sid)
      end

      it "returns phone number" do
        md5 = "123"
        phone_number = "4567"
        phone_number_sid = "PN" + md5

        ButsOiliwt::DB.write("chatbot", {})

        allow(Faker::Crypto).to receive(:md5).and_return(md5)
        allow(Faker::PhoneNumber).
          to receive(:cell_phone).
          and_return(phone_number)

        post "/v2/Accounts/123/IncomingPhoneNumbers.json"

        response = JSON.parse(last_response.body)

        expect(response["phone_number"]).to eq(phone_number)
        expect(response["sid"]).to eq(phone_number_sid)
      end
    end
  end
end
