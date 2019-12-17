defmodule DiscoveryApi.Data.RegistryMigrator do
  @moduledoc false
  alias SmartCity.Registry

  import Logger
  use Tesla

  plug Tesla.Middleware.JSON

  def migrate(env, limit, dryrun \\ true) do
    registry_datasets = Registry.Dataset.get_all!()
    Logger.warn("#{length(registry_datasets)} datasets in the registry")

    view_state_datasets = DiscoveryApi.Data.Model.get_all()
    Logger.warn("#{length(view_state_datasets)} datasets in the view state")

    registry_ids = registry_datasets |> Enum.map(fn dataset -> dataset.id end)
    view_state_ids = view_state_datasets |> Enum.map(fn dataset -> dataset.id end)

    difference_ids = registry_ids -- view_state_ids

    datasets_to_migrate =
      registry_datasets
      |> Enum.filter(fn dataset -> dataset.id in difference_ids end)
      |> Enum.take(limit)
      |> Enum.map(&Map.update!(&1, :technical, fn tech -> update_cadence(tech) end))
      |> Enum.map(&Map.update!(&1, :business, fn biz -> update_sub(biz) end))
      |> Enum.map(&Map.update!(&1, :technical, fn tech -> update_sub(tech) end))
      |> Enum.map(&SmartCity.Dataset.new/1)
      |> Enum.map(&elem(&1, 1))

    Logger.warn("#{length(datasets_to_migrate)} datasets to migrate")

    if dryrun do
      datasets_to_migrate
    else
      datasets_to_migrate |> Enum.map(fn dataset -> put_dataset(dataset, env) end)
    end
  end

  def put_dataset(dataset, env) do
    IO.puts("Posting dataset #{dataset.id}")

    case put("https://andi.#{env}.internal.smartcolumbusos.com/api/v1/dataset", Jason.encode!(dataset),
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, result} -> result
      error -> IO.puts("Got error posting dataset #{dataset.id}: #{inspect(error)}")
    end
  end

  def update_cadence(tech), do: Map.update!(tech, :cadence, fn _ -> "never" end)

  def update_sub(biz), do: Map.from_struct(biz)
end
