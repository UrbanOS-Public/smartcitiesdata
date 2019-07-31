defmodule DiscoveryApi.Test.Helper do
  @moduledoc """
  Utility functions for tests
  """
  alias DiscoveryApi.Data.Model
  alias SmartCity.TestDataGenerator, as: TDG

  def sample_model(values \\ %{}) do
    %Model{
      id: Faker.UUID.v4(),
      title: Faker.Lorem.word(),
      keywords: [Faker.Lorem.word(), Faker.Lorem.word()],
      organization: Faker.Lorem.word(),
      organizationDetails: %{} |> TDG.create_organization() |> Map.from_struct(),
      modifiedDate: Date.to_string(Faker.Date.backward(20)),
      fileTypes: [Faker.Lorem.characters(3), Faker.Lorem.characters(4)],
      description: Enum.join(Faker.Lorem.sentences(2..3), " "),
      schema: [%{:description => "a number", :name => "number", :type => "integer"}],
      sourceType: "remote",
      sourceUrl: Faker.Internet.url(),
      private: false,
      contactName: Faker.Name.first_name(),
      contactEmail: Faker.Internet.email(),
      license: "APL2",
      rights: "public",
      homepage: Faker.Internet.url(),
      spatial: Faker.Lorem.characters(10),
      temporal: Date.to_string(Faker.Date.date_of_birth()),
      publishFrequency: "10",
      conformsToUri: Faker.Internet.url(),
      describedByUrl: Faker.Internet.url(),
      describedByMimeType: "application/pdf",
      parentDataset: "none",
      issuedDate: Date.to_string(Faker.Date.date_of_birth()),
      language: "en-US",
      referenceUrls: Faker.Internet.url(),
      categories: [Faker.Lorem.word(), Faker.Lorem.word()],
      completeness: 0.95
    }
    |> Map.merge(values)
  end

  def ldap_user(values \\ %{}) do
    %{
      "cn" => ["bigbadbob"],
      "displayName" => ["big bad"],
      "dn" => "uid=bigbadbob,cn=users,cn=accounts",
      "ou" => ["People"],
      "sn" => ["bad"],
      "uid" => ["bigbadbob"],
      "uidNumber" => ["1501200034"]
    }
    |> Map.merge(values)
  end

  def ldap_group(values \\ %{}) do
    %{
      "cn" => ["this_is_a_group"],
      "dn" => "cn=this_is_a_group,ou=Group",
      "member" => ["cn=FirstUser,ou=People"],
      "objectClass" => ["top", "groupOfNames"]
    }
    |> Map.merge(values)
  end

  def extract_token(cookie_string) do
    cookie_string
    |> parse_cookie_string()
    |> Map.get(default_guardian_token_key())
  end

  def extract_response_cookie_as_map(conn) do
    conn
    |> Plug.Conn.get_resp_header("set-cookie")
    |> List.first()
    |> parse_cookie_string()
  end

  defp parse_cookie_string(cookie_string) do
    cookie_string
    |> String.split("; ")
    |> Enum.map(&String.split(&1, "="))
    |> Enum.reduce(%{}, fn key_value, acc -> Map.put(acc, Enum.at(key_value, 0), Enum.at(key_value, 1, true)) end)
  end

  def default_guardian_token_key(), do: Guardian.Plug.Keys.token_key() |> Atom.to_string()
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
      alias SmartCity.TestDataGenerator, as: TDG
      alias DiscoveryApi.Test.Helper

      # The default endpoint for testing
      @endpoint DiscoveryApiWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
