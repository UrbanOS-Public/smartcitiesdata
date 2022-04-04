defmodule AndiWeb.API.AuthControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  alias AndiWeb.AuthController
  alias Andi.Schemas.User

  test "creates user", %{conn: conn} do
    allow(User.create_or_update(any(), any()), return: {:ok, %{}})
    allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

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
