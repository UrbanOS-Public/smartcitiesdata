defmodule AndiWeb.Test.AuthConnCase.UnitCase do
  @moduledoc """
  This module produced authorized and unauthorized connections for testing against Andi in a unit test setup
  """

  use ExUnit.CaseTemplate
  use Placebo

  using do
    quote do
      import Phoenix.ConnTest
      import Plug.Conn
      alias AndiWeb.Router.Helpers, as: Routes

      @endpoint AndiWeb.Endpoint
    end
  end

  alias Andi.Test.AuthConnCase.AuthHelper

  setup _tags do
    disable_revocation_list()
    AuthHelper.build_connections()
  end

  setup_all do
    disable_revocation_list()
    exit_hook = AuthHelper.setup_jwks()
    on_exit(exit_hook)

    [auth_conn_case: %{disable_revocation_list: &disable_revocation_list/0}]
  end

  @doc """
  This exists b/c Placebo clears mocks on setup, so you can't just do it once in the helper case setup
  """
  def disable_revocation_list() do
    allow Guardian.DB.Token.find_by_claims(any()), return: nil
  end
end
