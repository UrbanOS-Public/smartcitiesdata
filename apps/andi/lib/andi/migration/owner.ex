defmodule Andi.Migration.Owner do
  @moduledoc false
  alias Andi.Repo
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets

  def transfer_all_datasets_to_owner(owner) do
    Datasets.get_all()
    |> Enum.map(fn dataset -> Repo.preload(dataset, [:owner]) end)
    |> Enum.each(fn dataset -> update_owner(dataset, owner) end)
  end

  def update_owner(dataset, owner) do
    new_changeset =
      Dataset.changeset_for_draft(
        dataset,
        %{
          owner: owner
        }
      )

    {:ok, new_dataset} = Datasets.save(new_changeset)
    new_dataset
  end
end
