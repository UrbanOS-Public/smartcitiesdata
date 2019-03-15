defmodule DiscoveryApiWeb.DataJsonView do
  use DiscoveryApiWeb, :view

  def render("get_data_json.json", %{datasets: datasets}) do
    translate_to_open_data_schema(datasets)
  end

  defp translate_to_open_data_schema(datasets) do
    %{
      conformsTo: "https://project-open-data.cio.gov/v1.1/schema",
      "@context": "https://project-open-data.cio.gov/v1.1/schema/catalog.jsonld",
      dataset: datasets
    }
  end
end
