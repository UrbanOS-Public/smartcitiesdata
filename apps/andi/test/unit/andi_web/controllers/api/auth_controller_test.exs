defmodule AndiWeb.API.AuthControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  alias AndiWeb.AuthController
  alias Andi.Schemas.User
  
  @moduletag timeout: 5000

  test "creates user", %{conn: conn} do
    # Set up :meck for modules that will be mocked
    modules_to_mock = [User, Brook.Event]
    
    # Clean up any existing mocks first
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
    
    # Set up fresh mocks
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    # Set up expectations for this test
    :meck.expect(User, :create_or_update, fn _, _ -> {:ok, %{}} end)
    :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
    
    auth = %{
      uid: "000-000",
      info: %{email: "someone@example.com", name: "Someone"},
      credentials: %{token: "super-legit"}
    }

    assigned = assign(conn, :ueberauth_auth, auth)

    AuthController.callback(assigned, %{})

    # Verify calls were made with expected arguments
    assert :meck.called(User, :create_or_update, [auth.uid, auth.info])
    
    # Clean up
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
  end
end
