defmodule DiscoveryApi.Test.Helper do
  @moduledoc """
  Utility functions for tests
  """
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Schemas.Users
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]
  import ExUnit.CaptureLog

  @instance_name DiscoveryApi.instance_name()

  def sample_model(values \\ %{}) do
    %Model{
      id: Faker.UUID.v4(),
      accessGroups: [],
      title: Faker.Lorem.word(),
      keywords: [Faker.Lorem.word(), Faker.Lorem.word()],
      organization: Faker.Lorem.word(),
      organizationDetails: %{} |> TDG.create_organization() |> Map.from_struct(),
      modifiedDate: Date.to_string(Faker.Date.backward(20)),
      fileTypes: Faker.File.file_extension(),
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
      contactName: Faker.Person.first_name(),
      contactEmail: Faker.Internet.email(),
      license: "APL2",
      rights: "public",
      homepage: Faker.Internet.url(),
      spatial: Faker.Lorem.word(),
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
    Brook.Test.with_event(@instance_name, fn ->
      Brook.ViewState.merge(:models, model.id, model)
    end)
  end

  def clear_saved_models() do
    Brook.Test.clear_view_state(@instance_name, :models)
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
    Process.sleep(20_000)
  end

  def create_persisted_user() do
    create_persisted_user(Auth.TestHelper.valid_jwt_sub())
  end

  def create_persisted_user(subject_id) do
    {:ok, user} = Users.create_or_update(subject_id, %{email: Faker.Internet.email(), name: Faker.Person.name()})
    user
  end

  def create_persisted_organization(map \\ %{}) do
    organization = TDG.create_organization(map)
    Brook.Event.send(@instance_name, "organization:update", :test, organization)

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

  def associate_user_with_organization(subject_id, organization_id) do
    {:ok, event} = SmartCity.UserOrganizationAssociate.new(%{subject_id: subject_id, org_id: organization_id, email: "test@example.com"})

    Brook.Event.send(@instance_name, "user:organization:associate", :test, event)

    Patiently.wait_for(
      fn -> user_associated_with_organization?(subject_id, organization_id) end,
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

    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

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

  defp user_associated_with_organization?(subject_id, organization_id) do
    case DiscoveryApi.Schemas.Users.get_user_with_organizations(subject_id, :subject_id) do
      {:ok, user} -> user.organizations |> Enum.any?(fn org -> org.id == organization_id end)
      _ -> false
    end
  end
end
