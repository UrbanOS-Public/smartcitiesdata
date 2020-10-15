defmodule Testing.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Additionally, the ecto database will be created and migrated.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using opts do
    repo_module = Keyword.fetch!(opts, :repo_module)

    quote do
      alias unquote(repo_module)

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Testing.DataCase

      def repo_module() do
        unquote(repo_module)
      end
    end
  end

  setup_all context do
    Application.ensure_all_started(:divo)
    Application.ensure_all_started(:ecto)
    repo_module = repo_module(context.module)
    Mix.Tasks.Ecto.Create.run([])
    Mix.Tasks.Ecto.Migrate.run([])
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo_module)
    Ecto.Adapters.SQL.Sandbox.mode(repo_module, :auto)

    :ok
  end

  setup tags do
    repo_module = repo_module(tags.module)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(repo_module)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(repo_module, {:shared, self()})
    end

    :ok
  end

  defp repo_module(test_module) do
    apply(test_module, :repo_module, [])
  end
end
