defmodule AndiWeb.DatasetControllerTest do
  use AndiWeb.ConnCase
  use Placebo

  @route "/api/v1/dataset"
  alias SmartCity.Dataset

  setup do
    allow(Kaffe.Producer.produce_sync(any(), any(), any()), return: :ok)
    allow(Dataset.write(any()), return: {:ok, "id"}, meck_options: [:passthrough])

    uuid = Faker.UUID.v4()

    request = %{
      "id" => uuid,
      "technical" => %{
        "dataName" => "dataset",
        "orgName" => "org",
        "stream" => false,
        "sourceUrl" => "https://example.com",
        "sourceType" => "stream",
        "sourceFormat" => "gtfs",
        "cadence" => 9000
      },
      "business" => %{
        "dataTitle" => "dataset title",
        "description" => "description",
        "modifiedDate" => "date",
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "license",
        "rights" => "rights information",
        "homepage" => ""
      }
    }

    message = %{
      "id" => uuid,
      "technical" => %{
        "dataName" => "dataset",
        "orgName" => "org",
        "systemName" => "org__dataset",
        "stream" => false,
        "sourceUrl" => "https://example.com",
        "sourceFormat" => "gtfs",
        "sourceType" => "stream",
        "cadence" => 9000,
        "headers" => %{},
        "queryParams" => %{},
        "transformations" => [],
        "validations" => [],
        "partitioner" => %{"query" => nil, "type" => nil},
        "schema" => []
      },
      "business" => %{
        "dataTitle" => "dataset title",
        "description" => "description",
        "modifiedDate" => "date",
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "license",
        "rights" => "rights information",
        "homepage" => ""
      }
    }

    {:ok, request: request, message: message, id: uuid}
  end

  describe "PUT /api/ with valid data" do
    setup %{conn: conn, request: request} do
      [conn: put(conn, @route, request)]
    end

    test "return a 201", %{conn: conn, id: id} do
      actual_id =
        conn
        |> json_response(201)
        |> Map.get("id")

      assert id == actual_id
    end

    test "sends dataset to kafka", %{message: message, id: id} do
      {:ok, struct} = Dataset.new(message)

      assert_called(
        Kaffe.Producer.produce_sync(
          "dataset-registry",
          id,
          Jason.encode!(struct)
        ),
        once()
      )
    end

    test "writes data to registry", %{message: message} do
      {:ok, struct} = Dataset.new(message)

      assert_called(Dataset.write(struct), once())
    end
  end

  describe "PUT /api/ with systemName" do
    setup %{conn: conn, request: request} do
      req = put_in(request, ["technical", "systemName"], "org__dataset")
      [conn: put(conn, @route, req)]
    end

    test "return 201", %{conn: conn, id: id} do
      actual_id =
        conn
        |> json_response(201)
        |> Map.get("id")

      assert id == actual_id
    end

    test "sends dataset to kafka", %{message: message, id: id} do
      {:ok, struct} = Dataset.new(message)

      assert_called(
        Kaffe.Producer.produce_sync(
          "dataset-registry",
          id,
          Jason.encode!(struct)
        ),
        once()
      )
    end

    test "writes to dataset registry", %{message: message} do
      {:ok, struct} = Dataset.new(message)
      assert_called(Dataset.write(struct), once())
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
end
