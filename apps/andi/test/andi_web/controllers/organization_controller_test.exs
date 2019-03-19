defmodule AndiWeb.OrganizationControllerTest do
  use ExUnit.Case
  use Placebo
  use AndiWeb.ConnCase

  @route "/api/v1/organization"
  alias SmartCity.Organization

  setup do
    allow(Andi.Kafka.send_to_kafka(any()), return: :ok)
    allow(Organization.write(any()), return: {:ok, "id"}, meck_options: [:passthrough])

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

  describe "post /api/ with valid data" do
    setup %{conn: conn, request: request} do
      [conn: post(conn, @route, request)]
    end

    test "returns 201", %{conn: conn, message: message} do
      assert json_response(conn, 201) == message
    end

    test "sends organization to kafka", %{message: message} do
      {:ok, struct} = Organization.new(message)
      assert_called(Andi.Kafka.send_to_kafka(struct), once())
    end

    test "writes organization to registry", %{message: message} do
      {:ok, struct} = Organization.new(message)
      assert_called(Organization.write(struct), once())
    end
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
