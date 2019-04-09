defmodule DiscoveryApiWeb.DatasetPreviewControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"

  setup do
    dataset_json = Jason.encode!(%{id: @dataset_id, systemName: @system_name})

    allow(Redix.command!(:redix, ["GET", "discovery-api:dataset:#{@dataset_id}"]), return: dataset_json)
    allow(Redix.command!(:redix, ["GET", "forklift:last_insert_date:#{@dataset_id}"]), return: nil)
    :ok
  end

  test "preview controller returns data from preview service", %{conn: conn} do
    list_of_maps = [
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
    ]

    encoded_maps =
      list_of_maps
      |> Jason.encode!()
      |> Jason.decode!()

    expected = %{"data" => encoded_maps}

    expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: list_of_maps)
    actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

    assert expected == actual
  end

  test "preview controller returns an empty list for an existing dataset with no data", %{conn: conn} do
    expected = %{"data" => []}

    expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview(@system_name), return: [])
    actual = conn |> get("/api/v1/dataset/#{@dataset_id}/preview") |> json_response(200)

    assert expected == actual
  end
end
