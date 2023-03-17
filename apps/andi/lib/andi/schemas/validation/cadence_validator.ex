defmodule Andi.Schemas.Validation.CadenceValidator do
  @moduledoc """
  Shared changeset validation logic for cadence
  """
  alias Crontab.CronExpression
  @invalid_seconds ["*", "*/1"]

  def validate(%{changes: %{cadence: cadence}} = changeset) when cadence in ["once", "never", "continuous"] do
    changeset
  end

  def validate(%{changes: %{cadence: crontab}} = changeset) do
    case validate_cron(crontab) do
      {:ok, _} -> changeset
      {:error, error_msg} -> Ecto.Changeset.add_error(changeset, :cadence, error_msg)
    end
  end

  def validate(changeset), do: changeset

  defp validate_cron(crontab) do
    crontab_list = String.split(crontab, " ")

    cond do
      Enum.count(crontab_list) not in [5, 6] ->
        {:error, "Invalid length"}

      Enum.count(crontab_list) == 6 and hd(crontab_list) in @invalid_seconds ->
        {:error, "Cron schedule has a minimum interval of every 2 seconds"}

      true ->
        CronExpression.Parser.parse(crontab, true)
    end
  end
end
