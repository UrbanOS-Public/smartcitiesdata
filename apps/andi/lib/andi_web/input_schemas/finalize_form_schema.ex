defmodule AndiWeb.InputSchemas.FinalizeFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools
  alias Crontab.CronExpression

  @invalid_seconds ["*", "*/1", "*/2", "*/3", "*/4", "*/5", "*/6", "*/7", "*/8", "*/9"]

  embedded_schema do
    field(:cadence, :string)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)
  def changeset(%__MODULE__{} = current, %{"cadence" => cadence}), do: changeset(current, %{cadence: cadence})

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, [:cadence])
    |> validate_required(:cadence, message: "is required")
    |> validate_cadence()
  end

  def changeset_from_andi_dataset(dataset) do
    dataset = StructTools.to_map(dataset)
    technical_changes = dataset.technical

    changeset(technical_changes)
  end

  def changeset_from_form_data(form_data) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset()
  end

  defp validate_cadence(%{changes: %{cadence: "once"}} = changeset), do: changeset
  defp validate_cadence(%{changes: %{cadence: "never"}} = changeset), do: changeset

  defp validate_cadence(%{changes: %{cadence: "continuous"}} = changeset) do
    changeset
    |> put_change(:cadence, "0/2 0 0 ? * * *")
  end

  defp validate_cadence(%{changes: %{cadence: crontab}} = changeset) do
    case validate_cron(crontab) do
      {:ok, _} -> changeset
      {:error, error_msg} -> add_error(changeset, :cadence, "#{error_msg}")
    end
  end

  defp validate_cadence(changeset), do: changeset

  defp validate_cron(crontab) do
    crontab_list = String.split(crontab, " ")

    cond do
      Enum.count(crontab_list) < 5 ->
        {:error, "Invalid length"}

      Enum.count(crontab_list) == 6 and hd(crontab_list) in @invalid_seconds ->
        {:error, "Cron schedule has a minimum interval of every 10 seconds"}

      true ->
        CronExpression.Parser.parse(crontab, true)
    end
  end
end
