defmodule DiscoveryApiWeb.Test.AuthConnCase.IntegrationCase do
  @moduledoc """
  This module produced authorized and unauthorized connections for testing against Discovery API in an integration setup
  """

  use ExUnit.CaseTemplate

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
    AuthHelper.build_connections()
  end

  setup_all do
    {exit_hook, _bypass} = AuthHelper.setup_jwks()
    on_exit(exit_hook)

    :ok
  end
end
