defmodule HmacTokenBehaviour do
  @moduledoc """
  Behaviour for the HmacToken module to enable mocking
  """
  
  @callback create_hmac_token(any(), any()) :: any()
  @callback valid_hmac_token(any(), any(), any()) :: boolean()
end