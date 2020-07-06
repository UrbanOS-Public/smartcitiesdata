defmodule AndiWeb.InputSchemas.FinalizeFormSchema.FutureSchedule do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:date, :date)
    field(:time, :time)
  end

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, [:date, :time])
    |> validate_required([:date, :time])
    |> validate_date_in_future()
  end

  defp validate_date_in_future(changeset) do
    date = get_field(changeset, :date)
    time = get_field(changeset, :time)

    case {date, time} do
      {bad, worse} when is_nil(bad) or is_nil(worse) -> changeset
      {bad, worse} when bad == "" or worse == "" -> changeset
      {date, time} ->
        localized_datetime = date_and_time_to_local_datetime(date, time)
        if DateTime.diff(localized_datetime, local_now()) <= 0 do
          add_error(changeset, :date, "can't be in past")
          |> add_error(:time, "can't be in past")
        else
          changeset
        end
    end
  end

  defp date_and_time_to_local_datetime(date, time) do
    "#{Date.to_string(date)}T#{Time.to_string(time)}"
    |> Timex.parse!("{ISOdate}T{ISOtime}")
    |> Timex.to_datetime(local_timezone())
  end

  defp local_now() do
    {:ok, dt} = DateTime.now(local_timezone())

    dt
  end

  def local_timezone() do
    Application.get_env(:andi, :timezone, "America/New_York")
  end
end

defmodule AndiWeb.InputSchemas.FinalizeFormSchema.RepeatingSchedule do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @cast_fields [:week, :month, :day, :hour, :minute, :second]

  embedded_schema do
    field(:week, :string)
    field(:month, :string)
    field(:day, :string)
    field(:hour, :string)
    field(:minute, :string)
    field(:second, :string)
  end

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, @cast_fields)
    |> validate_required(@cast_fields)
    |> validate_formats(@cast_fields, ~r|^[/.*0-9]+$|)
  end

  defp validate_formats(changeset, fields, format) do
    Enum.reduce(fields, changeset, fn field, acc_changeset ->
      validate_format(acc_changeset, field, format)
    end)
  end
end

defmodule AndiWeb.InputSchemas.FinalizeFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.CronTools
  alias AndiWeb.InputSchemas.FinalizeFormSchema.FutureSchedule
  alias AndiWeb.InputSchemas.FinalizeFormSchema.RepeatingSchedule
  alias Andi.InputSchemas.StructTools

  @invalid_seconds ["*", "*/1", "*/2", "*/3", "*/4", "*/5", "*/6", "*/7", "*/8", "*/9"]

  embedded_schema do
    field(:cadence_type, :string, default: "once")
    field(:cadence, :string)
    embeds_one(:future_schedule, FutureSchedule)
    embeds_one(:repeating_schedule, RepeatingSchedule)
  end

  def changeset(changes), do: changeset(%__MODULE__{}, changes)
  def changeset(%__MODULE__{} = current, %{"cadence" => cadence}), do: changeset(current, %{cadence: cadence})
  def changeset(%__MODULE__{} = current, %{cadence: cadence} = _tech) do
    cadence_type = CronTools.determine_cadence_type(cadence)
    repeating_cronlist = CronTools.cronstring_to_cronlist_with_default!(cadence_type, cadence)
    future_schedule = CronTools.cronlist_to_future_schedule(repeating_cronlist)

    changes = %{
      cadence_type: cadence_type,
      future_schedule: future_schedule,
      repeating_schedule: repeating_cronlist
    }

    changeset(current, changes)
  end

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, [:cadence_type, :cadence])
    |> cast_embed(:future_schedule, required: true)
    |> cast_embed(:repeating_schedule)
    |> validate_cadence()
  end

  def changeset_from_andi_dataset(dataset) do
    dataset = StructTools.to_map(dataset)
    technical_changes = dataset.technical

    changeset(technical_changes)
  end

  defp validate_cadence(%{changes: %{cadence: "once"}} = changeset), do: changeset
  defp validate_cadence(%{changes: %{cadence: "never"}} = changeset), do: changeset

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
