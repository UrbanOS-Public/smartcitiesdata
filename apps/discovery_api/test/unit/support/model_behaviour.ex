defmodule ModelBehaviour do
  @moduledoc """
  Behaviour for the Model module to enable mocking
  """
  
  @callback get(binary()) :: any() | nil
  @callback get_all() :: list()
  @callback get_all(list()) :: list()
  @callback delete(binary()) :: any()
  @callback get_completeness({binary(), any()}) :: any()
  @callback get_count_maps(binary()) :: any()
  @callback to_table_info(any()) :: map()
end