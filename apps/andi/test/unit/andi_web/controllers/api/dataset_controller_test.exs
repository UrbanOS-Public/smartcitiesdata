defmodule AndiWeb.API.DatasetControllerTest do
  use AndiWeb.ConnCase
  use Placebo

  @route "/api/v1/dataset"
  @get_datasets_route "/api/v1/datasets"
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.DatasetCache
  alias Andi.Services.DatasetStore

  import Andi
  import SmartCity.Event, only: [dataset_disable: 0, dataset_delete: 0]

  setup do
    GenServer.call(DatasetCache, :reset)

    example_dataset_1 = TDG.create_dataset(%{})

    example_dataset_1 =
      example_dataset_1
      |> struct_to_map_with_string_keys()

    example_dataset_2 = TDG.create_dataset(%{})

    example_dataset_2 =
      example_dataset_2
      |> struct_to_map_with_string_keys()

    example_datasets = [example_dataset_1, example_dataset_2]

    allow(DatasetStore.get_all(),
      return: {:ok, [example_dataset_1, example_dataset_2]},
      meck_options: [:passthrough]
    )

    allow(Brook.Event.send(instance_name(), any(), :andi, any()), return: :ok, meck_options: [:passthrough])

    uuid = Faker.UUID.v4()

    request = %{
      "id" => uuid,
      "technical" => %{
        "dataName" => "dataset",
        "orgId" => "org-123-456",
        "orgName" => "org",
        "stream" => false,
        "sourceUrl" => "https://example.com",
        "sourceType" => "stream",
        "sourceFormat" => "gtfs",
        "cadence" => 9000,
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
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "license",
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

    {:ok, request: request, message: message, example_datasets: example_datasets}
  end

  describe "PUT /api/ without systemName" do
    setup %{conn: conn, request: request} do
      {_, request} = pop_in(request, ["technical", "systemName"])
      [conn: put(conn, @route, request)]
    end

    test "return a 201", %{conn: conn} do
      system_name =
        conn
        |> json_response(201)
        |> get_in(["technical", "systemName"])

      assert system_name == "org__dataset"
    end

    test "writes data to event stream", %{message: message} do
      {:ok, struct} = Dataset.new(message)

      assert_called(Brook.Event.send(instance_name(), any(), :andi, struct), once())
    end
  end

  test "put returns 400 when systemName matches existing systemName", %{
    conn: conn,
    request: request
  } do
    org_name = request["technical"]["orgName"]
    data_name = request["technical"]["dataName"]

    existing_dataset =
      TDG.create_dataset(
        id: "existing-ds1",
        technical: %{
          dataName: data_name,
          orgName: org_name,
          systemName: "#{org_name}__#{data_name}"
        }
      )

    DatasetCache.put(existing_dataset)

    %{"errors" => errors} =
      conn
      |> put(@route, request)
      |> json_response(400)

    assert errors["dataName"] == ["existing dataset has the same orgName and dataName"]
  end

  test "put returns 400 when systemName has dashes", %{
    conn: conn
  } do
    org_name = "what-a-great"
    data_name = "system-name"

    new_dataset =
      TDG.create_dataset(
        id: "my-new-dataset",
        technical: %{
          dataName: data_name,
          orgName: org_name,
          systemName: "#{org_name}__#{data_name}"
        }
      )

    %{"errors" => errors} =
      conn
      |> put(@route, new_dataset |> Jason.encode!() |> Jason.decode!())
      |> json_response(400)

    assert errors["orgName"] == ["cannot contain dashes"]
    assert errors["dataName"] == ["cannot contain dashes"]
  end

  test "put returns 400 when modifiedDate is invalid", %{
    conn: conn
  } do
    new_dataset =
      TDG.create_dataset(
        id: "my-new-dataset",
        technical: %{dataName: "my_little_dataset"}
      )
      |> struct_to_map_with_string_keys()
      |> put_in(["business", "modifiedDate"], "badDate")

    %{"errors" => errors} =
      conn
      |> put(@route, new_dataset)
      |> json_response(400)

    assert errors["modifiedDate"] == ["is invalid"]
  end

  test "put returns 400 and errors when fields are invalid", %{
    conn: conn
  } do
    new_dataset =
      TDG.create_dataset(
        id: "my-new-dataset",
        business: %{
          dataTitle: "",
          description: nil,
          contactEmail: "not-a-valid-email",
          license: "",
          publishFrequency: nil,
          benefitRating: nil
        },
        technical: %{
          sourceFormat: "",
          sourceHeaders: %{"" => "where's my key"},
          sourceQueryParams: %{"" => "where's MY key"}
        }
      )
      |> struct_to_map_with_string_keys()
      |> delete_in([
        ["business", "contactName"],
        ["business", "orgTitle"],
        ["business", "issuedDate"],
        ["business", "riskRating"],
        ["technical", "sourceFormat"],
        ["technical", "private"]
      ])

    %{"errors" => actual_errors} =
      conn
      |> put(@route, new_dataset)
      |> json_response(400)

    expected_error_keys = [
      "benefitRating",
      "dataTitle",
      "description",
      "contactName",
      "contactEmail",
      "issuedDate",
      "license",
      "publishFrequency",
      "orgTitle",
      "private",
      "riskRating",
      "sourceFormat",
      "sourceHeaders",
      "sourceQueryParams"
    ]

    for key <- expected_error_keys do
      assert Map.has_key?(actual_errors, key) == true
    end

    assert Map.keys(actual_errors) |> length() == length(expected_error_keys)
  end

  test "put trims fields on dataset", %{
    conn: conn
  } do
    new_dataset =
      TDG.create_dataset(
        id: " my-new-dataset  ",
        technical: %{
          dataName: "   the_data_name ",
          orgName: " the_org_name   "
        },
        business: %{
          contactName: " some  body  ",
          keywords: ["  a keyword", " another keyword", "etc"]
        }
      )

    response =
      conn
      |> put(@route, new_dataset |> Jason.encode!() |> Jason.decode!())
      |> json_response(201)

    assert response["id"] == "my-new-dataset"
    assert response["business"]["contactName"] == "some  body"
    assert response["business"]["keywords"] == ["a keyword", "another keyword", "etc"]
    assert response["technical"]["dataName"] == "the_data_name"
    assert response["technical"]["orgName"] == "the_org_name"
  end

  describe "POST /dataset/disable" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:disable event", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: :ok)

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(200)

      assert_called(Brook.Event.send(instance_name(), dataset_disable(), :andi, dataset))
    end

    @tag capture_log: true
    test "does not send dataset:disable event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      allow(DatasetStore.get(any()), return: {:ok, nil})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: :ok)

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(404)

      refute_called(Brook.Event.send(instance_name(), dataset_disable(), :andi, dataset))
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: {:error, "Mistakes were made"})

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(500)
    end
  end

  describe "POST /dataset/delete" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:delete event", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: :ok)

      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(200)

      assert_called(Brook.Event.send(instance_name(), dataset_delete(), :andi, dataset))
    end

    @tag capture_log: true
    test "does not send dataset:delete event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      allow(DatasetStore.get(any()), return: {:ok, nil})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: :ok)

      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(404)

      refute_called(Brook.Event.send(instance_name(), dataset_delete(), :andi, dataset))
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: {:error, "Mistakes were made"})

      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(500)
    end
  end

  describe "PUT /api/ with systemName" do
    setup %{conn: conn, request: request} do
      req = put_in(request, ["technical", "systemName"], "org__dataset_akdjbas")
      [conn: put(conn, @route, req)]
    end

    test "return 201", %{conn: conn} do
      system_name =
        conn
        |> json_response(201)
        |> get_in(["technical", "systemName"])

      assert system_name == "org__dataset"
    end

    test "writes to event stream", %{message: message} do
      {:ok, struct} = Dataset.new(message)
      assert_called(Brook.Event.send(instance_name(), any(), :andi, struct), once())
    end
  end

  @tag capture_log: true
  test "PUT /api/ without data returns 500", %{conn: conn} do
    conn = put(conn, @route)
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  @tag capture_log: true
  test "PUT /api/ with improperly shaped data returns 500", %{conn: conn} do
    conn = put(conn, @route, %{"id" => 5, "operational" => 2})
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  describe "GET dataset definitions from /api/dataset/" do
    setup %{conn: conn, request: request} do
      [conn: get(conn, @get_datasets_route, request)]
    end

    @tag capture_log: true
    test "returns a 200", %{conn: conn, example_datasets: example_datasets} do
      actual_datasets =
        conn
        |> json_response(200)

      assert MapSet.new(example_datasets) == MapSet.new(actual_datasets)
    end
  end

  test "PUT /api/ dataset passed without UUID generates UUID for dataset", %{conn: conn, request: request} do
    {_, request} = pop_in(request, ["id"])
    conn = put(conn, @route, request)

    uuid =
      conn
      |> json_response(201)
      |> get_in(["id"])

    assert uuid != nil
  end

  describe "GET /api/dataset/:dataset_id" do
    test "should return a given dataset when it exists", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      allow(DatasetStore.get(dataset.id), return: {:ok, dataset})

      conn = get(conn, "/api/v1/dataset/#{dataset.id}")

      response = conn |> json_response(200)
      assert Map.get(response, "id") == dataset.id
    end

    test "should return a 404 when requested dataset does not exist", %{conn: conn} do
      allow(DatasetStore.get(any()), return: {:ok, nil})

      conn = get(conn, "/api/v1/dataset/123")

      assert 404 == conn.status
    end
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
