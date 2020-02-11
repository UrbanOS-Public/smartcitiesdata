defmodule Pipeline.Writer.TableWriter.Statement do
  @moduledoc false

  alias Pipeline.Writer.TableWriter.Statement.{Create, Insert}

  require Logger

  defmodule FieldTypeError do
    @moduledoc false
    defexception message: "Encountered an unsupported field type"
  end

  def create(%{table: name, as: select}) do
    {:ok, "create table #{name} as (#{select})"}
  end

  def create(%{table: name, schema: schema, format: format}) do
    {:ok, Create.compose(name, schema, format)}
  rescue
    e in FieldTypeError ->
      {:error, e.message}

    e ->
      {:error, "Unable to parse schema: #{inspect(e)}"}
  end

  def create(%{table: name, schema: schema}) do
    {:ok, Create.compose(name, schema)}
  rescue
    e in FieldTypeError ->
      {:error, e.message}

    e ->
      {:error, "Unable to parse schema: #{inspect(e)}"}
  end

  def insert(config, content) do
    with {:ok, statement} <- Insert.compose(config, content) do
      statement
    end
  end

  def drop(%{table: table}) do
    "drop table if exists #{table}"
  end

  def alter(%{table: table, alteration: change}) do
    "alter table #{table} #{change}"
  end
end
