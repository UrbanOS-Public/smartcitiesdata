defmodule Forklift do
  @moduledoc """
  Message Format

  key = "..."
  value =
    {
      dataset_id: "..."
      data: {...}/[...],
    }
  topic = "<k>"
  partition = "<i>"

  Kaffe => HandleMessage => GenServer(dataset_id, message(s)) => Statement(dataset_id, schema, agg_messages) => Prestige(statement)
  """

end
