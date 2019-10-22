defmodule AndiWeb.DatasetControllerTest do
  use AndiWeb.ConnCase
  use Placebo

  @route "/api/v1/dataset"
  @get_datasets_route "/api/v1/datasets"
  alias SmartCity.Registry.Dataset, as: RegDataset
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG
  import Andi
  import SmartCity.Event, only: [dataset_disable: 0]

  setup do
    example_dataset_1 = TDG.create_dataset(%{})

    example_dataset_1 =
      example_dataset_1
      |> Jason.encode!()
      |> Jason.decode!()

    example_dataset_2 = TDG.create_dataset(%{})

    example_dataset_2 =
      example_dataset_2
      |> Jason.encode!()
      |> Jason.decode!()

    example_datasets = [example_dataset_1, example_dataset_2]

    allow(RegDataset.write(any()),
      return: {:ok, "id"},
      meck_options: [:passthrough]
    )

    allow(Brook.get_all_values(instance_name(), any()),
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
        "schema" => [],
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
        "dataTitle" => "dataset title",
        "description" => "description",
        "modifiedDate" => "",
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "license",
        "rights" => "rights information",
        "homepage" => "",
        "keywords" => []
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
      |> Jason.encode!()
      |> Jason.decode!()

    {:ok, request: request, message: message, example_datasets: example_datasets}
  end

  describe "PUT /api/ without systemName" do
    setup %{conn: conn, request: request} do
      allow Brook.get_all_values!(instance_name(), any()), return: []
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
      {:ok, _struct} = Dataset.new(message)

      assert_called(Brook.Event.send(instance_name(), any(), :andi, any()), once())
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

    allow Brook.get_all_values!(instance_name(), any()), return: [existing_dataset]

    response =
      conn
      |> put(@route, request)
      |> json_response(400)

    assert %{"reason" => ["Existing dataset has the same orgName and dataName"]} == response
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

    allow(Brook.get_all_values!(any(), :dataset), return: [])

    %{"reason" => errors} =
      conn
      |> put(@route, new_dataset |> Jason.encode!() |> Jason.decode!())
      |> json_response(400)

    joined_errors = Enum.join(errors, ", ")

    assert String.contains?(joined_errors, "orgName")
    assert String.contains?(joined_errors, "dataName")
    assert String.contains?(joined_errors, "dashes")
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

    allow(Brook.get_all_values!(any(), :dataset), return: [])

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
      allow(Brook.get(instance_name(), any(), any()), return: {:ok, dataset})
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
      allow(Brook.get(instance_name(), any(), any()), return: {:ok, nil})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: :ok)

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(404)

      refute_called(Brook.Event.send(instance_name(), dataset_disable(), :andi, dataset))
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      allow(Brook.get(instance_name(), any(), any()), return: {:ok, dataset})
      allow(Brook.Event.send(instance_name(), any(), any(), any()), return: {:error, "Mistakes were made"})

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(500)
    end
  end

  describe "PUT /api/ with systemName" do
    setup %{conn: conn, request: request} do
      allow Brook.get_all_values!(instance_name(), any()), return: []
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
    allow Brook.get_all_values!(instance_name(), any()), return: []

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
      allow(Brook.get(instance_name(), :dataset, dataset.id), return: {:ok, dataset})

      conn = get(conn, "/api/v1/dataset/#{dataset.id}")

      response = conn |> json_response(200)
      assert Map.get(response, "id") == dataset.id
    end

    test "should return a 404 when requested dataset does not exist", %{conn: conn} do
      allow(Brook.get(instance_name(), :dataset, any()), return: {:ok, nil})

      conn = get(conn, "/api/v1/dataset/123")

      assert 404 == conn.status
    end
  end
end
