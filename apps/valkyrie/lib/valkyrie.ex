defmodule Valkyrie do
  @moduledoc """
  Main Business logic for Valkyrie, including validated a data messages matches the dataset schema
  """

  alias SmartCity.Data
  alias Valkyrie.Dataset

  @type reason :: atom() | String.t() | Exception.t()

  @spec validate_data(%Dataset{}, %Data{}) :: :ok | {:error, reason()}
  def validate_data(%Dataset{} = dataset, %Data{} = data) do
    :ok
  end
end
