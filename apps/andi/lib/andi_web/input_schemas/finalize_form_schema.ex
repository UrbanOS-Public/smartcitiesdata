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
        iso_string = "#{Date.to_string(date)}T#{Time.to_string(time)}"
        {:ok, dt} = NaiveDateTime.from_iso8601(iso_string)
        if Date.diff(dt, NaiveDateTime.utc_now()) <= 0 do
          add_error(changeset, :date, "can't be in past")
          |> add_error(:time, "can't be in past")
        else
          changeset
        end
    end
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

  embedded_schema do
    field(:cadence_type, :string, default: "once")
    embeds_one(:future_schedule, FutureSchedule)
    embeds_one(:repeating_schedule, RepeatingSchedule)
  end

  def changeset(%__MODULE__{} = current, %{"cadence" => cadence}), do: changeset(current, %{cadence: cadence})
  def changeset(%__MODULE__{} = current, %{cadence: cadence} = tech) do
    cadence_type = CronTools.determine_cadence_type(cadence)
    repeating_cronlist = CronTools.to_repeating(cadence_type, cadence)
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
    |> cast(changes, [:cadence_type])
    |> cast_embed(:future_schedule)
    |> cast_embed(:repeating_schedule)
  end
end
