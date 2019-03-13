defmodule AndiWeb.OrganizationControllerTest do
  use ExUnit.Case
  use Placebo
  use AndiWeb.ConnCase

  @route "/api/v1/organization"
  alias SCOS.OrganizationMessage

  setup do
    allow(Kaffe.Producer.produce_sync(any(), any(), any()), return: :ok)
    allow(Andi.Kafka.send_to_kafka(any()), return: :ok)
    on_exit(fn -> Placebo.unstub() end)

    request = %{
      "id" => "uuid",
      "orgName" => "Org Name",
      "orgTitle" => "Org Title"
    }

    message = %{
      "id" => "uuid",
      "orgName" => "Org Name",
      "orgTitle" => "Org Title",
      "description" => nil,
      "homepage" => nil,
      "logoUrl" => nil
    }

    {:ok, request: request, message: message}
  end

  test "post /api/ with valid data returns 201", %{conn: conn, request: request, message: message} do
    conn = post(conn, @route, request)
    assert json_response(conn, 201) == message

    {:ok, struct} = OrganizationMessage.new(message)
    assert_called(Andi.Kafka.send_to_kafka(struct), once())
  end

  test "post /api/ without data returns 500", %{conn: conn} do
    conn = post(conn, @route)
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  test "post /api/ with improperly shaped data returns 500", %{conn: conn} do
    conn = post(conn, @route, %{"invalidData" => 2})
    assert json_response(conn, 500) =~ "Unable to process your request"
  end
end
