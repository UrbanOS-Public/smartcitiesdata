defmodule DiscoveryApiWeb.Test.AuthConnCase.UnitCase do
  @moduledoc """
  This module produced authorized and unauthorized connections for testing against Discovery API in a unit test setup
  """

  use ExUnit.CaseTemplate
  use Placebo

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
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
  This exists b/c Placebo clears mocks on setup, so you can't just do it once in the helper case setup
  """
  def disable_revocation_list() do
    allow Guardian.DB.Token.find_by_claims(any()), return: nil
  end

  def disable_user_addition() do
    allow DiscoveryApi.Schemas.Users.create_or_update(any(), any()), return: {:ok, :good}
  end
end
