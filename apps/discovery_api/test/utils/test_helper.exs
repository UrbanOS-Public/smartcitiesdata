defmodule DiscoveryApi.Test.Helper do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset

  def sample_dataset(values \\ %{}) do
    %Dataset{
      id: Faker.UUID.v4(),
      title: Faker.Lorem.word(),
      keywords: [Faker.Lorem.characters(5), Faker.Lorem.characters(6)],
      organization: Faker.Lorem.word(),
      orgId: Faker.UUID.v4(),
      modified: Date.to_string(Faker.Date.backward(20)),
      fileTypes: [Faker.Lorem.characters(3), Faker.Lorem.characters(4)],
      description: Enum.join(Faker.Lorem.sentences(2..3), " "),
      sourceType: "remote",
      sourceUrl: Faker.Internet.url()
    }
    |> Map.merge(values)
  end
end

defmodule DiscoveryApiWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
      import DiscoveryApiWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint DiscoveryApiWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
