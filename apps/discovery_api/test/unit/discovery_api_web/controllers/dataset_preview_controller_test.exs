defmodule DiscoveryApiWeb.DatasetPreviewControllerTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo

  test "preview controller returns data from preview service", %{conn: conn} do
    dataset_id = Faker.Lorem.characters(3..10)

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

    expect(DiscoveryApiWeb.DatasetPrestoQueryService.preview(any()), return: list_of_maps)
    actual = conn |> get("/api/v1/dataset/#{dataset_id}/preview") |> json_response(200)

    assert expected == actual
  end
end
