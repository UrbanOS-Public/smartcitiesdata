defmodule AndiWeb.DatasetControllerTest do
  use AndiWeb.ConnCase
  use Placebo

  @route "/api/v1/dataset"

  setup do
    allow(Kaffe.Producer.produce_sync(any(), any(), any()), return: :ok)
    on_exit(fn -> Placebo.unstub() end)
  end

  test "PUT /api/ with valid data returns 201", %{conn: conn} do
    conn = put(conn, @route, %{"id" => 5, "operational" => 2, "business" => 4})
    assert json_response(conn, 201) == %{"business" => 4, "id" => "5", "operational" => 2}

    assert_called(
      Kaffe.Producer.produce_sync(
        "dataset-registry",
        "5",
        "{\"business\":4,\"id\":\"5\",\"operational\":2}"
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
