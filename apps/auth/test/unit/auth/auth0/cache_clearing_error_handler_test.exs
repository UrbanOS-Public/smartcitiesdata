defmodule Auth.Auth0.CacheClearingErrorHandlerTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo

  import Plug.Test
  import Plug.Conn

  alias Auth.Auth0.CachedJWKS
  alias Auth.TestHelper

  describe "verify_X in pipeline" do
    test "retries with a cache clear for invalid token errors" do
      token = TestHelper.valid_jwt()
      successful_claims = %{"claims" => "yes"}

      allow CachedJWKS.clear(), return: :whatever
      allow Guardian.decode_and_verify(any(), any(), any(), any()), seq: [{:error, {:invalid_token, :old_jwks_cache}}, {:ok, successful_claims}]

      conn = conn(:get, "/does/not/matter")
      |> put_req_header("authorization", "Bearer #{token}")

      assert %{halted: false} = conn = Guardian.Plug.Pipeline.call(
        conn,
        module: Test.TokenHandler.Invalid,
        error_handler: Test.ErrorHandler
      )
      |> Guardian.Plug.VerifyHeader.call([halt: false])

      assert successful_claims == Guardian.Plug.current_claims(conn, [])

      assert_called CachedJWKS.clear(), times: 1
    end

    test "gives up after one failed retry" do
      token = TestHelper.valid_jwt()

      allow CachedJWKS.clear(), return: :whatever
      allow Guardian.decode_and_verify(any(), any(), any(), any()), return: {:error, {:invalid_token, :truly_broken}}

      conn = conn(:get, "/does/not/matter")
      |> put_req_header("authorization", "Bearer #{token}")

      assert %{
        halted: true,
        status: 401
      } = Guardian.Plug.Pipeline.call(
        conn,
        module: Test.TokenHandler.Invalid,
        error_handler: Test.ErrorHandler
      )
      |> Guardian.Plug.VerifyHeader.call([halt: false])

      assert_called CachedJWKS.clear(), times: 1
    end
  end
end

defmodule Test.ErrorHandler do
  @moduledoc false

  use Auth.Guardian.CacheClearingErrorHandler

  def auth_error(conn, error, _opts) do
    Plug.Conn.resp(conn, 401, Jason.encode!(%{error: error}))
  end
end

defmodule Test.TokenHandler.Invalid do
  @moduledoc false

  use Auth.Guardian.TokenHandler, otp_app: :auth
end
