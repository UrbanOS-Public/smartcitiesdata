defmodule FixtureHelper do
  @moduledoc false

  alias SmartCity.Dataset

  def dataset(overrides) do
    {:ok, dataset_message} =
      Dataset.new(
        deep_merge(
          %{
            business: %{
              dataTitle: "Stuff",
              description: "crap",
              modifiedDate: "something",
              orgTitle: "SCOS",
              contactName: "Jalson",
              contactEmail: "something@email.com",
              license: "MIT"
            },
            technical: %{
              dataName: "name",
              cadence: 100_000,
              sourceUrl: "https://does-not-matter-url.com",
              sourceFormat: "gtfs",
              queryParams: %{},
              headers: %{
                Authorization: "Basic xdasdgdasgdsgd"
              },
              systemName: "scos",
              source_type: "ingest",
              stream: "IDK",
              orgName: "Whatever",
              schema: []
            }
          },
          Map.new(overrides)
        )
      )

    dataset_message
  end

  def deep_merge(left, right), do: Map.merge(left, right, &deep_resolve/3)
  defp deep_resolve(_key, %{} = left, %{} = right), do: deep_merge(left, right)
  defp deep_resolve(_key, _left, right), do: right
end
