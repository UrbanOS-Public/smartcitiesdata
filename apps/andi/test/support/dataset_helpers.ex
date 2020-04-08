defmodule DatasetHelpers do
  @moduledoc false

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  require Placebo

  def create_dataset(overrides) do
    changes =
      overrides
      |> TDG.create_dataset()
      |> InputConverter.prepare_smrt_dataset_for_casting()

    Dataset.changeset_for_draft(%Dataset{}, changes)
    |> Ecto.Changeset.apply_changes()
  end

  def add_dataset_to_repo(dataset, opts \\ []) do
    unique = Keyword.get(opts, :unique, true)

    Placebo.allow(Datasets.get(dataset.id), return: dataset)
    Placebo.allow(Datasets.is_unique?(dataset.id, :_, :_), return: unique)
    Placebo.allow(Datasets.is_unique?(nil, :_, :_), return: unique)
  end

  def ensure_dataset_removed_from_repo(id, _opts \\ []) do
    Placebo.allow(Datasets.get(id), return: nil)
  end

  def replace_all_datasets_in_repo(datasets, _opts \\ []) do
    Placebo.allow(Datasets.get_all(), return: datasets, meck_options: [:passthrough])
  end
end
