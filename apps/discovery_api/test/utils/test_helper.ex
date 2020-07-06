defmodule DiscoveryApi.Test.Helper do
  @moduledoc """
  Utility functions for tests
  """
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Test.AuthHelper
  alias DiscoveryApi.Auth.Auth0.CachedJWKS
  alias DiscoveryApiWeb.Auth.TokenHandler
  alias DiscoveryApi.Auth.GuardianConfigurator
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]
  import ExUnit.CaptureLog

  @instance DiscoveryApi.instance()

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
      schema: [
        %{
          :description => "a number",
          :name => "number",
          :type => "integer",
          :pii => "false",
          :biased => "false",
          :masked => "N/A",
          :demographic => "None"
        },
        %{
          :description => "a name",
          :name => "name",
          :type => "string",
          :pii => "true",
          :biased => "true",
          :masked => "yes",
          :demographic => "Other"
        }
      ],
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
      completeness: %{
        "total_score" => Faker.random_uniform(),
        "record_count" => Faker.random_between(1, 1000),
        "fields" => %{"one" => %{"count" => 1, "required" => false}}
      },
      systemName: "#{Faker.Lorem.word()}__#{Faker.Lorem.word()}"
    }
    |> Map.merge(values)
  end

  def save_model(model) do
    Brook.Test.with_event(@instance, fn ->
      Brook.ViewState.merge(:models, model.id, model)
    end)
  end

  def clear_saved_models() do
    Brook.Test.clear_view_state(@instance, :models)
  end

  def auth0_setup() do
    secret_key = Application.get_env(:discovery_api, TokenHandler) |> Keyword.get(:secret_key)
    GuardianConfigurator.configure(issuer: AuthHelper.valid_issuer())

    jwks = AuthHelper.valid_jwks()
    CachedJWKS.set(jwks)

    bypass = Bypass.open()

    really_far_in_the_future = 3_000_000_000_000
    AuthHelper.set_allowed_guardian_drift(really_far_in_the_future)

    Application.put_env(
      :discovery_api,
      :user_info_endpoint,
      "http://localhost:#{bypass.port}/userinfo"
    )

    Bypass.stub(bypass, "GET", "/userinfo", fn conn ->
      Plug.Conn.resp(conn, :ok, Jason.encode!(%{"email" => "x@y.z"}))
    end)

    exit_fn = fn ->
      AuthHelper.set_allowed_guardian_drift(0)
      GuardianConfigurator.configure(secret_key: secret_key)
    end

    %{subject_id: AuthHelper.valid_jwt_sub(), token: AuthHelper.valid_jwt(), exit_fn: exit_fn}
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

  def stringify_keys(map) do
    map
    |> Enum.map(fn field ->
      field
      |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
      |> Enum.into(%{})
    end)
  end

  def wait_for_brook_to_be_ready() do
    Process.sleep(5_000)
  end

  def create_persisted_user(subject_id) do
    {:ok, user} = Users.create_or_update(subject_id, %{email: Faker.Internet.email()})
    user
  end

  def create_persisted_organization(map \\ %{}) do
    organization = TDG.create_organization(map)
    Brook.Event.send(DiscoveryApi.instance(), "organization:update", :test, organization)

    Patiently.wait_for(
      fn ->
        DiscoveryApi.Schemas.Organizations.get_organization!(organization.id) != nil
      end,
      dwell: 500,
      max_tries: 100
    )
    |> case do
      :ok -> :ok
      _ -> raise "An error occured in setting up the organization correctly in: #{__MODULE__}"
    end

    organization
  end

  def associate_user_with_organization(user_id, organization_id) do
    {:ok, event} = SmartCity.UserOrganizationAssociate.new(%{user_id: user_id, org_id: organization_id})

    Brook.Event.send(DiscoveryApi.instance(), "user:organization:associate", :test, event)

    Patiently.wait_for(
      fn -> user_associated_with_organization?(user_id, organization_id) end,
      dwell: 500,
      mat_tries: 10
    )
    |> case do
      :ok -> :ok
      _ -> raise "An error occured in setting up the user-organization association correctly in: #{__MODULE__}"
    end
  end

  def create_schema_organization(overrides \\ %{}) do
    smart_city_organization = SmartCity.TestDataGenerator.create_organization(overrides)

    %DiscoveryApi.Schemas.Organizations.Organization{
      id: smart_city_organization.id,
      description: smart_city_organization.description,
      name: smart_city_organization.orgName,
      title: smart_city_organization.orgTitle,
      logo_url: smart_city_organization.logoUrl,
      homepage: smart_city_organization.homepage
    }
  end

  def create_persisted_dataset(id, name, orgName, private \\ false) do
    organization = create_persisted_organization(%{id: "org#{id}", orgName: orgName})

    dataset =
      TDG.create_dataset(%{
        id: id,
        technical: %{
          private: private,
          orgId: organization.id,
          orgName: organization.orgName,
          dataName: name,
          systemName: "#{organization.orgName}__#{name}"
        }
      })

    Brook.Event.send(DiscoveryApi.instance(), dataset_update(), __MODULE__, dataset)

    eventually(fn ->
      nil != Model.get(dataset.id)
    end)

    table = dataset.technical.systemName

    prestige_session =
      DiscoveryApi.prestige_opts()
      |> Keyword.merge(receive_timeout: 10_000)
      |> Prestige.new_session()

    capture_log(fn ->
      Prestige.query(
        prestige_session,
        ~s|create table if not exists "#{table}" (id integer, name varchar)|
      )
    end)

    {table, dataset.id}
  end

  defp user_associated_with_organization?(user_id, organization_id) do
    case DiscoveryApi.Schemas.Users.get_user_with_organizations(user_id) do
      {:ok, user} -> user.organizations |> Enum.any?(fn org -> org.id == organization_id end)
      _ -> false
    end
  end
end
