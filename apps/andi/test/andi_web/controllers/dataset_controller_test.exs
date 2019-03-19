defmodule AndiWeb.DatasetControllerTest do
  use AndiWeb.ConnCase
  use Placebo

  @route "/api/v1/dataset"
  alias SmartCity.Dataset

  setup do
    allow(Kaffe.Producer.produce_sync(any(), any(), any()), return: :ok)
    allow(Dataset.write(any()), return: {:ok, "id"}, meck_options: [:passthrough])

    request = %{
      "id" => "uuid",
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
      "id" => "uuid",
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
        "keywords" => [],
        "modifiedDate" => "date",
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "license",
        "rights" => "rights information",
        "homepage" => ""
      }
    }

    {:ok, request: request, message: message}
  end

  describe "PUT /api/ with valid data" do
    setup %{conn: conn, request: request} do
      [conn: put(conn, @route, request)]
    end

    test "return a 201", %{conn: conn, message: message} do
      assert json_response(conn, 201) == message
    end

    test "sends dataset to kafka", %{message: message} do
      {:ok, struct} = Dataset.new(message)

      assert_called(
        Kaffe.Producer.produce_sync(
          "dataset-registry",
          "uuid",
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

    test "return 201", %{conn: conn, message: message} do
      assert json_response(conn, 201) == message
    end

    test "sends dataset to kafka", %{message: message} do
      {:ok, struct} = Dataset.new(message)

      assert_called(
        Kaffe.Producer.produce_sync(
          "dataset-registry",
          "uuid",
          Jason.encode!(struct)
        ),
        once()
      )
    end

    test "writes to dataset registry", %{message: message} do
      {:ok, struct} = Dataset.new(message)
      assert_called Dataset.write(struct), once()
    end
  end

  test "PUT /api/ without data returns 500", %{conn: conn} do
    conn = put(conn, @route)
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  test "PUT /api/ with improperly shaped data returns 500", %{conn: conn} do
    conn = put(conn, @route, %{"id" => 5, "operational" => 2})
    assert json_response(conn, 500) =~ "Unable to process your request"
  end
end
