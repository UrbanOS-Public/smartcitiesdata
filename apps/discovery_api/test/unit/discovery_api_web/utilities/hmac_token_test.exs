defmodule DiscoveryApiWeb.Utilities.HmacTokenTest do
  use ExUnit.Case
  use Properties, otp_app: :discovery_api

  alias DiscoveryApiWeb.Utilities.HmacToken

  @dataset_id "54e0ed3b-1acb-4220-9e9d-2fe542e51f16"
  @expiration_timestamp_dec_31_2050 2_556_118_800
  @expected_hmac_token "23817C59EDADF275664961DC4E5112D371D457D8CBDEB95DCB73BF0FCAFF3B46"

  getter(:presign_key, generic: true)

  describe "create_hmac_token" do
    test "it creates an hmac_token with dataset id and timestamp" do
      assert @expected_hmac_token == HmacToken.create_hmac_token(@dataset_id, @expiration_timestamp_dec_31_2050)
    end
  end

  describe "valid_hmac_token" do
    test "it returns false if hmac token does not match expected" do
      assert false == HmacToken.valid_hmac_token("THIS_IS_A_BAD_TOKEN", @dataset_id, @expiration_timestamp_dec_31_2050)
    end

    test "it returns false if hmac token is expired" do
      time_before_now = 1_578_675_735
      expired_hmac_token = :crypto.mac(:hmac, :sha256, presign_key(), "#{@dataset_id}/#{time_before_now}") |> Base.encode16()

      assert false == HmacToken.valid_hmac_token(expired_hmac_token, @dataset_id, time_before_now)
    end

    test "it returns true if we have a token that matches and is not expired" do
      assert true == HmacToken.valid_hmac_token(@expected_hmac_token, @dataset_id, @expiration_timestamp_dec_31_2050)
    end
  end
end
