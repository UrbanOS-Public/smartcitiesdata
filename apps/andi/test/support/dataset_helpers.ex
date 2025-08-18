defmodule DatasetHelpers do
  @moduledoc false

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  def create_dataset(overrides) do
    changes =
      overrides
      |> TDG.create_dataset()
      |> InputConverter.prepare_smrt_dataset_for_casting()

    Dataset.changeset_for_draft(%Dataset{}, changes)
    |> Ecto.Changeset.apply_changes()
  end

  def create_empty_dataset() do
    Dataset.changeset_for_draft(%Dataset{}, %{technical: %{}, business: %{}, id: UUID.uuid4()})
    |> Ecto.Changeset.apply_changes()
  end

  def add_dataset_to_repo(dataset, opts \\ []) do
    unique = Keyword.get(opts, :unique, true)

    # Use :meck to set up expectations
    setup_meck_modules()
    :meck.expect(Datasets, :get, fn id when id == dataset.id -> dataset; _ -> nil end)
    :meck.expect(Datasets, :is_unique?, fn
      id, _, _ when id == dataset.id -> unique
      nil, _, _ -> unique
      _, _, _ -> true
    end)
    :meck.expect(Andi.Repo, :all, fn _ -> [{"Top Level", dataset.technical.id}] end)
  end

  def ensure_dataset_removed_from_repo(id, _opts \\ []) do
    setup_meck_modules()
    :meck.expect(Datasets, :get, fn dataset_id when dataset_id == id -> nil; other_id -> :meck.passthrough([other_id]) end)
  end

  def replace_all_datasets_in_repo(datasets, _opts \\ []) do
    setup_meck_modules()
    :meck.expect(Datasets, :get_all, fn -> datasets end)
  end

  defp setup_meck_modules do
    modules = [Datasets, Andi.Repo]
    Enum.each(modules, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
  end
end
