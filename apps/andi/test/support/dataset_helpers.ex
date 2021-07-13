defmodule DatasetHelpers do
  @moduledoc false

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  import Placebo

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

    Placebo.allow(Datasets.get(dataset.id), return: dataset, meck_options: [:passthrough])
    Placebo.allow(Datasets.is_unique?(dataset.id, :_, :_), return: unique, meck_options: [:passthrough])
    Placebo.allow(Datasets.is_unique?(nil, :_, :_), return: unique, meck_options: [:passthrough])
    Placebo.allow(Andi.Repo.all(:_), return: [{"Top Level", dataset.technical.id}])
  end

  def ensure_dataset_removed_from_repo(id, _opts \\ []) do
    Placebo.allow(Datasets.get(id), return: nil)
  end

  def replace_all_datasets_in_repo(datasets, _opts \\ []) do
    Placebo.allow(Datasets.get_all(), return: datasets, meck_options: [:passthrough])
  end
end
