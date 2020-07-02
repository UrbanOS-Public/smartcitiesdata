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
          add_error(changeset, :date, "can't be in past", validation: "can't be in past")
          |> add_error(:time, "can't be in past", validation: "can't be in past")
        else
          changeset
        end
    end
  end

  defp date_and_time_to_local_datetime(date, time) do
    "#{Date.to_string(date)}T#{Time.to_string(time)}"
    |> Timex.parse!("{ISOdate}T{ISOtime}")
    |> Timex.to_datetime(Andi.timezone())
  end

  defp local_now() do
    {:ok, dt} = DateTime.now(Andi.timezone())

    dt
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
    field(:quick_cron, :string, default: "")
    embeds_one(:future_schedule, FutureSchedule)
    embeds_one(:repeating_schedule, RepeatingSchedule)
  end

  def changeset(%__MODULE__{} = current, %{"cadence" => cadence}), do: changeset(current, %{cadence: cadence})
  def changeset(%__MODULE__{} = current, %{cadence: cadence} = _tech) do
    cadence_type = CronTools.determine_cadence_type(cadence)
    repeating_cronlist = CronTools.cronstring_to_cronlist_with_default!(cadence_type, cadence)
    future_schedule = CronTools.cronlist_to_future_schedule(repeating_cronlist)

    changes = %{
      cadence_type: cadence_type,
      future_schedule: future_schedule,
      repeating_schedule: repeating_cronlist,
      quick_cron: ""
    }

    changeset(current, changes)
  end

  def changeset(%__MODULE__{} = current, changes) do
    current
    |> cast(changes, [:cadence_type, :quick_cron])
    |> cast_embed(:future_schedule, required: true)
    |> cast_embed(:repeating_schedule)
  end
end
