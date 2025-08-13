defmodule DiscoveryApiWeb.Utilities.HmacToken do
  @moduledoc """
  Functions for working with HMAC tokens to do presigned URLs and possibly other things
  """
  use Properties, otp_app: :discovery_api

  getter(:presign_key, generic: true)

  def create_hmac_token(dataset_id, expiration_timestamp) do
    :crypto.mac(:hmac, :sha256, presign_key(), "#{dataset_id}/#{expiration_timestamp}") |> Base.encode16()
  end

  def valid_hmac_token(key, dataset_id, expiration_timestamp) do
    current_unix_timestamp = DateTime.utc_now() |> DateTime.to_unix()

    if expiration_timestamp < current_unix_timestamp do
      false
    else
      if create_hmac_token(dataset_id, expiration_timestamp) != key do
        false
      else
        true
      end
    end
  end
end
