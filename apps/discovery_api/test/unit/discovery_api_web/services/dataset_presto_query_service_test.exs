defmodule DiscoveryApiWeb.DatasetPrestoQueryServiceTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApiWeb.DatasetPrestoQueryService

  test "preview should query presto for given table" do
    dataset = "things_in_the_fire"
    response_from_execute = %{something: "Unique", id: Faker.UUID.v4()}

    list_of_maps = [
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)},
      %{"id" => Faker.UUID.v4(), name: Faker.Lorem.characters(3..10)}
    ]

    expect(Prestige.execute("select * from #{dataset} limit 50", rows_as_maps: true),
      return: response_from_execute
    )

    expect(Prestige.prefetch(response_from_execute), return: list_of_maps)

    result = DatasetPrestoQueryService.preview(dataset)
    assert list_of_maps == result
  end

  test "preview_columns should query presto for given columns" do
    dataset = "things_in_the_fire"
    response_from_execute = %{something: "Unique", id: Faker.UUID.v4()}

    list_of_columns = ["col_a", "col_b", "col_c"]

    unprocessed_columns = [["col_a", "varchar", "", ""], ["col_b", "varchar", "", ""], ["col_c", "integer", "", ""]]

    expect(Prestige.execute("show columns from #{dataset}"), return: response_from_execute)

    expect(Prestige.prefetch(response_from_execute), return: unprocessed_columns)

    result = DatasetPrestoQueryService.preview_columns(dataset)
    assert list_of_columns == result
  end
end
