defmodule AndiWeb.DatasetControllerTest do
  use AndiWeb.ConnCase
  use Placebo

  @route "/api/v1/dataset"
  alias SCOS.RegistryMessage

  setup do
    allow(Kaffe.Producer.produce_sync(any(), any(), any()), return: :ok)
    on_exit(fn -> Placebo.unstub() end)

    request = %{
      "id" => "uuid",
      "technical" => %{
        "dataName" => "dataset",
        "orgName" => "org",
        "stream" => false,
        "sourceUrl" => "https://example.com",
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
        "cadence" => 9000,
        "headers" => %{},
        "queryParams" => %{},
        "transformations" => [],
        "validations" => [],
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

  test "PUT /api/ with valid data returns 201", %{conn: conn, request: request, message: message} do
    conn = put(conn, @route, request)
    assert json_response(conn, 201) == message

    {:ok, struct} = RegistryMessage.new(message)

    assert_called(
      Kaffe.Producer.produce_sync(
        "dataset-registry",
        "uuid",
        RegistryMessage.encode!(struct)
      ),
      once()
    )
  end

  test "PUT /api/ with systemName returns 201", %{conn: conn, request: request, message: message} do
    req = put_in(request, ["technical", "systemName"], "org__dataset")
    conn = put(conn, @route, req)
    assert json_response(conn, 201) == message

    {:ok, struct} = RegistryMessage.new(message)

    assert_called(
      Kaffe.Producer.produce_sync(
        "dataset-registry",
        "uuid",
        RegistryMessage.encode!(struct)
      ),
      once()
    )
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
