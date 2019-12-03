defmodule DiscoveryApi.Test.Helper do
  @moduledoc """
  Utility functions for tests
  """
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Schemas.Users
  alias SmartCity.TestDataGenerator, as: SC_TDG

  @ldap_people_ou "People"

  def sample_model(values \\ %{}) do
    %Model{
      id: Faker.UUID.v4(),
      title: Faker.Lorem.word(),
      keywords: [Faker.Lorem.word(), Faker.Lorem.word()],
      organization: Faker.Lorem.word(),
      organizationDetails: %{} |> SC_TDG.create_organization() |> Map.from_struct(),
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

  def ldap_user(values \\ %{}) do
    %{
      "cn" => ["bigbadbob"],
      "displayName" => ["big bad"],
      "dn" => "uid=bigbadbob,cn=users,cn=accounts",
      "ou" => [@ldap_people_ou],
      "sn" => ["bad"],
      "uid" => ["bigbadbob"],
      "uidNumber" => ["1501200034"]
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

  def setup_ldap() do
    Paddle.authenticate([cn: "admin"], "admin")
    Paddle.add([ou: @ldap_people_ou], objectClass: ["top", "organizationalunit"], ou: @ldap_people_ou)
  end

  def create_ldap_user(username) do
    dn = [uid: username, ou: @ldap_people_ou]

    user_request = [
      objectClass: ["account", "posixAccount"],
      cn: username,
      uid: username,
      loginShell: "/bin/bash",
      homeDirectory: "/home/user",
      uidNumber: 501,
      gidNumber: 100,
      userPassword: "{SSHA}/02KaNTR+p0r0KSDfDZfFQiYgyekBsdH"
    ]

    case Paddle.add(dn, user_request) do
      status when status in [:ok, {:error, :entryAlreadyExists}] ->
        {:ok, [_user | _]} = Paddle.get(base: "uid=#{username},ou=#{@ldap_people_ou}")
        create_persisted_user(username)

      error ->
        raise error
    end
  end

  def get_token_from_login(username, password \\ "admin") do
    %{status_code: 200, headers: headers} =
      "http://localhost:4000/api/v1/login"
      |> HTTPoison.get!([], hackney: [basic_auth: {username, password}])
      |> Map.from_struct()

    {"token", token} = Enum.find(headers, fn {header, _value} -> header == "token" end)
    token
  end

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
    organization = SC_TDG.create_organization(map)
    Brook.Event.send(DiscoveryApi.instance(), "organization:update", :test, organization)

    Patiently.wait_for(
      fn ->
        DiscoveryApi.Schemas.Organizations.get_organization!(organization.id) != nil
      end,
      dwell: 500,
      mat_tries: 20
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

  defp user_associated_with_organization?(user_id, organization_id) do
    case DiscoveryApi.Schemas.Users.get_user_with_organizations(user_id) do
      {:ok, user} -> user.organizations |> Enum.any?(fn org -> org.id == organization_id end)
      _ -> false
    end
  end
end
