defmodule DiscoveryApiWeb.Test.AuthConnCase.UnitCase do
  @moduledoc """
  This module produced authorized and unauthorized connections for testing against Discovery API in a unit test setup
  """

  use ExUnit.CaseTemplate
  # Temporarily commenting out Mox to fix the on_exit issue
  # import Mox

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      # import Mox
      alias DiscoveryApiWeb.Router.Helpers, as: Routes

      @endpoint DiscoveryApiWeb.Endpoint
    end
  end

  alias DiscoveryApi.Test.AuthConnCase.AuthHelper

  setup _tags do
    disable_revocation_list()
    {exit_hook, bypass} = AuthHelper.setup_jwks()
    on_exit(exit_hook)

    AuthHelper.build_connections()
    |> Keyword.put(:bypass, bypass)
  end

  setup_all do
    disable_revocation_list()

    [auth_conn_case: %{disable_revocation_list: &disable_revocation_list/0, disable_user_addition: &disable_user_addition/0}]
  end

  @doc """
  This exists to stub common functions that many tests need
  """
  def disable_revocation_list() do
    # In test mode, revocation is handled by TestGuardian
    :ok
  end

  def disable_user_addition() do  
    # In test mode, user creation is handled by TestGuardian
    :ok
  end
end
