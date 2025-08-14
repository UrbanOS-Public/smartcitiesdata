defmodule PrestoServiceBehaviour do
  @moduledoc """
  Behaviour for the PrestoService module to enable mocking
  """
  
  @callback get_affected_tables(any(), binary()) :: {:ok, list()} | {:error, any()}
  @callback is_select_statement?(binary()) :: boolean()
  @callback preview(any(), binary(), integer(), list()) :: list()
  @callback preview(any(), binary(), integer()) :: list()
  @callback preview_columns(list()) :: list()
  @callback get_column_names(any(), any(), any()) :: {:ok, list()} | {:error, any()}
  @callback build_query(any(), any(), any(), any()) :: {:ok, binary()} | {:error, any()}
  @callback format_select_statement_from_schema(list()) :: binary()
  @callback map_prestige_results_to_schema(any(), list()) :: any()
end