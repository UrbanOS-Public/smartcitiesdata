defmodule DiscoveryApi.Data.ProjectOpenDataHandler do
  @moduledoc false
  alias DiscoveryApi.Data.Persistence
  alias DiscoveryApi.Data.Mapper
  @name_space "discovery-api:project-open-data:"

  def process_project_open_data_event(%SmartCity.Dataset{} = dataset) do
    case dataset.technical.private do
      false -> persist(dataset)
      _ -> {:ok, :not_persisted}
    end
  end

  defp persist(%SmartCity.Dataset{} = dataset) do
    host = Application.get_env(:discovery_api, DiscoveryApiWeb.Endpoint)[:url][:host]
    base_url = "https://discoveryapi.#{host}"
    podms_map = Mapper.to_podms(dataset, base_url)
    Persistence.persist(@name_space <> dataset.id, podms_map)
  end
end
