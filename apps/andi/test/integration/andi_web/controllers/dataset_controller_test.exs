defmodule Andi.DatasetControllerTest do
  use ExUnit.Case

  use Andi.DataCase
  use Tesla
  use Properties, otp_app: :andi

  @moduletag shared_data_connection: true

  import SmartCity.TestHelper, only: [eventually: 1]
  import SmartCity.Event, only: [dataset_disable: 0, dataset_delete: 0, dataset_update: 0]
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations

  plug(Tesla.Middleware.BaseUrl, "http://localhost:4000")
  getter(:kafka_broker, generic: true)

  setup do
    smrt_org = TDG.create_organization(%{}) 
    Organizations.update(smrt_org)
    [org_id: smrt_org.id]
  end

  describe "dataset disable" do
    test "sends dataset:disable event", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceType: "remote"}})
      {:ok, _} = create(dataset)

      eventually(fn ->
        {:ok, value} = DatasetStore.get(dataset.id)
        assert value != nil
      end)

      post("/api/v1/dataset/disable", %{id: dataset.id} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == dataset_disable() && String.contains?(message.value, dataset.id)
          end)

        assert 1 == length(values)
      end)
    end
  end

  describe "dataset delete" do
    test "sends dataset:delete event", %{org_id: org_id} do
      dataset = TDG.create_dataset(%{organization_id: org_id, technical: %{sourceType: "remote"}})
      {:ok, _} = create(dataset)

      eventually(fn ->
        {:ok, value} = DatasetStore.get(dataset.id)
        assert value != nil
      end)

      post("/api/v1/dataset/delete", %{id: dataset.id} |> Jason.encode!(), headers: [{"content-type", "application/json"}])

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.filter(fn message ->
            message.key == dataset_delete() && String.contains?(message.value, dataset.id)
          end)

        assert 1 = length(values)
      end)

      eventually(fn ->
        {:ok, value} = DatasetStore.get(dataset.id)
        assert value == nil
      end)
    end
  end

  describe "dataset put" do
    setup do
      uuid = Faker.UUID.v4()
      smrt_org = TDG.create_organization(%{}) 
      Organizations.update(smrt_org)
      request = %{
        "id" => uuid,
        "organization_id" => smrt_org.id,
        "technical" => %{
          "dataName" => Faker.Person.first_name(),
          "stream" => false,
          "extractSteps" => [%{"type" => "http", "context" => %{"url" => "example.com", "action" => "GET"}}],
          "sourceUrl" => "https://example.com",
          "sourceType" => "stream",
          "sourceFormat" => "application/gtfs+protobuf",
          "cadence" => "*/9000 * * * * *",
          "schema" => [%{name: "billy", type: "writer"}],
          "private" => false,
          "headers" => %{
            "accepts" => "application/foobar"
          },
          "sourceQueryParams" => %{
            "apiKey" => "foobar"
          },
          "systemName" => "org__dataset",
          "transformations" => [],
          "validations" => []
        },
        "business" => %{
          "benefitRating" => 0.5,
          "dataTitle" => "dataset title",
          "description" => "description",
          "modifiedDate" => "",
          "contactName" => "contact name",
          "contactEmail" => "contact@email.com",
          "license" => "https://www.test.net",
          "rights" => "rights information",
          "homepage" => "",
          "keywords" => [],
          "issuedDate" => "2020-01-01T00:00:00Z",
          "publishFrequency" => "all day, ey'r day",
          "riskRating" => 1.0
        },
        "_metadata" => %{
          "intendedUse" => [],
          "expectedBenefit" => []
        }
      }

      message =
        request
        |> SmartCity.Helpers.to_atom_keys()
        |> TDG.create_dataset()
        |> struct_to_map_with_string_keys()

      {_, request} = pop_in(request, ["technical", "systemName"])
      assert {:ok, %{status: 201, body: body}} = create(request)
      response = Jason.decode!(body)

      eventually(fn ->
        assert DatasetStore.get(request["id"]) != {:ok, nil}
      end)

      {:ok, response: response, message: message, org: smrt_org}
    end

    test "assigns a system name", %{message: message, response: response, org: org} do
      system_name = get_in(response, ["technical", "systemName"])
      {:ok, struct} = SmartCity.Dataset.new(message)

      assert system_name == org.orgName <> "__" <> struct.technical.dataName
    end

    test "writes data to event stream", %{message: message, org: org} do
      {:ok, struct} = SmartCity.Dataset.new(message)

      struct = put_in(struct, [:technical, :systemName], org.orgName <> "__" <> struct.technical.dataName)

      eventually(fn ->
        values =
          Elsa.Fetch.fetch(kafka_broker(), "event-stream")
          |> elem(2)
          |> Enum.map(fn message ->
            {:ok, brook_message} = Brook.Deserializer.deserialize(message.value)
            brook_message
          end)
          |> Enum.filter(fn message ->
            message.type == dataset_update()
          end)
          |> Enum.map(fn message ->
            message.data
          end)

        assert struct in values
      end)
    end

    test "put returns 400 when systemName matches existing systemName", %{message: message, org: org} do
      {:ok, struct} = SmartCity.Dataset.new(message)
      org_name = org.orgName
      data_name = struct.technical.dataName

      existing_dataset =
        TDG.create_dataset(
          id: "existing-ds1",
          organization_id: org.id,
          technical: %{
            extractSteps: [%{type: "http", context: %{action: "GET", url: "example.com"}}],
            dataName: data_name,
            systemName: "#{org_name}__#{data_name}"
          }
        )

      eventually(fn ->
        assert Datasets.get(struct.id) != nil
      end)

      {:ok, %{status: 400, body: body}} = create(existing_dataset)

      errors =
        Jason.decode!(body)
        |> Map.get("errors")
        |> Map.get("technical")

      assert errors["dataName"] == ["existing dataset has the same orgName and dataName"]
    end

    test "put returns 400 when systemName has dashes" do
      org_name = "what-a-great"
      data_name = "system-name"
      smrt_org = TDG.create_organization(%{orgName: org_name})
      Organizations.update(smrt_org)
      new_dataset =
        TDG.create_dataset(
          id: "my-new-dataset",
          organization_id: smrt_org.id,
          technical: %{
            extractSteps: [%{type: "http", context: %{action: "GET", url: "example.com"}}],
            dataName: data_name,
            systemName: "#{org_name}__#{data_name}"
          }
        )

      {:ok, %{status: 400, body: body}} = create(new_dataset)

      errors =
        Jason.decode!(body)
        |> Map.get("errors")
        |> Map.get("technical")

      assert errors["dataName"] == ["cannot contain dashes"]
    end

    test "put returns 400 when modifiedDate is invalid", %{org: org} do
      new_dataset =
        TDG.create_dataset(
          id: "my-new-dataset",
          organization_id: org.id,
          technical: %{extractSteps: [%{type: "http", context: %{action: "GET", url: "example.com"}}], dataName: "my_little_dataset"}
        )
        |> struct_to_map_with_string_keys()
        |> put_in(["business", "modifiedDate"], "badDate")

      {:ok, %{status: 400, body: body}} = create(new_dataset)

      errors =
        Jason.decode!(body)
        |> Map.get("errors")
        |> Map.get("business")

      assert errors["modifiedDate"] == ["is invalid"]
    end

    test "put returns 400 and errors when fields are invalid", %{org: org} do
      new_dataset =
        TDG.create_dataset(
          id: "my-new-dataset",
          organization_id: org.id,
          business: %{
            dataTitle: "",
            description: nil,
            contactEmail: "not-a-valid-email",
            license: "",
            publishFrequency: nil,
            benefitRating: nil
          },
          technical: %{
            extractSteps: [%{type: "http", context: %{action: "GET", url: "example.com"}}],
            sourceFormat: "",
            sourceHeaders: %{"" => "where's my key"},
            sourceQueryParams: %{"" => "where's MY key"}
          }
        )
        |> struct_to_map_with_string_keys()
        |> delete_in([
          ["business", "contactName"],
          ["business", "issuedDate"],
          ["business", "riskRating"],
          ["technical", "sourceFormat"],
          ["technical", "private"]
        ])

      {:ok, %{status: 400, body: body}} = create(new_dataset)

      actual_errors =
        Jason.decode!(body)
        |> Map.get("errors")

      expected_error_keys = [
        ["business", "contactName"],
        ["business", "contactEmail"],
        ["business", "issuedDate"],
        ["business", "license"],
        ["business", "publishFrequency"],
        ["business", "dataTitle"],
        ["business", "description"],
        ["business", "benefitRating"],
        ["business", "riskRating"],
        ["technical", "private"],
        ["technical", "sourceFormat"],
        ["technical", "sourceHeaders"],
        ["technical", "sourceQueryParams"]
      ]

      for key <- expected_error_keys do
        assert get_in(actual_errors, key) != nil
      end

      assert Map.keys(actual_errors["technical"]) |> length() ==
               Enum.filter(expected_error_keys, fn [area, _] -> area == "technical" end) |> length()

      assert Map.keys(actual_errors["business"]) |> length() ==
               Enum.filter(expected_error_keys, fn [area, _] -> area == "business" end) |> length()
    end

    test "put trims fields on dataset",  %{org: org} do
      new_dataset =
        TDG.create_dataset(
          organization_id: org.id,
          id: " my-new-dataset  ",
          technical: %{
            dataName: "   the_data_name ",
            sourceType: "remote"
          },
          business: %{
            contactName: " some  body  ",
            keywords: ["  a keyword", " another keyword", "etc"]
          }
        )

      {:ok, %{status: 201, body: body}} = create(new_dataset)
      response = Jason.decode!(body)

      eventually(fn ->
        assert DatasetStore.get("my-new-dataset") != {:ok, nil}
      end)

      assert response["id"] == "my-new-dataset"
      assert response["business"]["contactName"] == "some  body"
      assert response["business"]["keywords"] == ["a keyword", "another keyword", "etc"]
      assert response["technical"]["dataName"] == "the_data_name"
    end

    test "put with a system name does not reflect it back", %{org: org} do
      new_dataset = TDG.create_dataset(organization_id: org.id, technical: %{systemName: "this_will__get_tossed", sourceType: "remote"})

      {:ok, %{status: 201, body: body}} = create(new_dataset)

      eventually(fn ->
        assert DatasetStore.get(new_dataset.id) != {:ok, nil}
      end)

      system_name =
        Jason.decode!(body)
        |> get_in(["technical", "systemName"])

      assert system_name != "this_will__get_tossed"
    end

    test "PUT /api/ dataset passed without UUID generates UUID for dataset", %{org: org} do
      new_dataset = TDG.create_dataset(%{organization_id: org.id, technical: %{extractSteps: [%{type: "http", context: %{action: "GET", url: "example.com"}}]}})
      {_, new_dataset} = pop_in(new_dataset, ["id"])

      {:ok, %{status: 201, body: body}} = create(new_dataset)

      eventually(fn ->
        assert DatasetStore.get(new_dataset.id) != {:ok, nil}
      end)

      uuid =
        Jason.decode!(body)
        |> get_in(["id"])

      assert uuid != nil
    end

    test "returns 400 when cron string is longer than 6 characters", %{org: org} do
      new_dataset =
        TDG.create_dataset(%{organization_id: org.id})
        |> put_in([:technical, :cadence], "0 * * * * * *")
        |> struct_to_map_with_string_keys()

      {:ok, %{status: 400, body: _body}} = create(new_dataset)
    end
  end

  describe "dataset get" do
    test "andi doesn't return server in response headers" do
      {:ok, %Tesla.Env{headers: headers}} = get("/api/v1/datasets", headers: [{"content-type", "application/json"}])
      refute headers |> Map.new() |> Map.has_key?("server")
    end
  end

  defp create(dataset) do
    struct = Jason.encode!(dataset)
    put("/api/v1/dataset", struct, headers: [{"content-type", "application/json"}])
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp delete_in(data, paths) do
    Enum.reduce(paths, data, fn path, working ->
      working |> pop_in(path) |> elem(1)
    end)
  end
end
