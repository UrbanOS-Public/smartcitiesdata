defmodule Pipeline.Writer.TableWriter.Statement do
  @moduledoc "TODO"

  alias Pipeline.Writer.TableWriter.Statement.{Create, Insert}

  require Logger

  defmodule FieldTypeError do
    @moduledoc false
    defexception message: "Encountered an unsupported field type"
  end

  def create(config) do
    {:ok, Create.compose(config.name, config.schema)}
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
end
