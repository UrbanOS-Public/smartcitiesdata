defmodule AndiWeb.API.AuthControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Mock

  alias AndiWeb.AuthController
  alias Andi.Schemas.User

  test "creates user", %{conn: conn} do
    with_mocks([
      {User, [], [create_or_update: fn _, _ -> {:ok, %{}} end]},
      {Brook.Event, [], [send: fn _, _, _, _ -> :ok end]}
    ]) do
      auth = %{
        uid: "000-000",
        info: %{email: "someone@example.com", name: "Someone"},
        credentials: %{token: "super-legit"}
      }

      assigned = assign(conn, :ueberauth_auth, auth)

      AuthController.callback(assigned, %{})

      assert_called(Andi.Schemas.User.create_or_update(auth.uid, auth.info))
    end
  end
end
