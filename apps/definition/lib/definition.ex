defmodule Definition do
  @moduledoc """
  Defines a base module for extensibly defining struct types,
  their schemas (validation performed by Norm), and functions
  for managing the lifecycle of those structs across revisions
  over the lifetime of a system.
  """

  @callback new(map | keyword, term) :: {:ok, struct} | {:error, term}
  @callback new!(map | keyword, term) :: struct
  @callback from_json(String.t(), term) :: {:ok, struct} | {:error, term}
  @callback schema() :: %Norm.Core.Schema{}
  @callback on_new(struct, term) :: {:ok, struct} | {:error, term}
  @callback migrate(struct) :: {:ok, struct} | {:error, term}

  @spec identifier(term) :: String.t()
  def identifier(%{dataset_id: dataset_id, subset_id: subset_id}) do
    identifier(dataset_id, subset_id)
  end

  @spec identifier(dataset_id :: String.t(), subset_id :: String.t()) :: String.t()
  def identifier(dataset_id, subset_id) do
    "#{dataset_id}__#{subset_id}"
  end

  defmacro __using__(opts) do
    quote do
      @behaviour Definition
      @before_compile Definition

      defmodule InputError do
        defexception [:message]
      end

      @schema Keyword.fetch!(unquote(opts), :schema)

      @impl Definition
      def new(%{} = input, id_generator) do
        map =
          Enum.map(input, fn {key, val} -> {:"#{key}", val} end)
          |> Map.new()
          |> Map.put_new_lazy(:id, fn -> id_generator.uuid4() end)

        struct(__MODULE__, map)
        |> on_new(id_generator)
        |> Ok.map(&migrate/1)
        |> Ok.map(&Norm.conform(&1, @schema.s()))
      end

      def new(input, id_generator) when is_list(input) do
        case Keyword.keyword?(input) do
          true ->
            Map.new(input) |> new(id_generator)

          false ->
            {:error, InputError.exception(message: input)}
        end
      end

      def new!(input, id_generator) do
        case new(input, id_generator) do
          {:ok, value} -> value
          {:error, reason} -> raise reason
        end
      end

      @impl Definition
      def on_new(input, _id_generator) do
        {:ok, input}
      end

      @impl Definition
      def from_json(input, id_generator) when is_binary(input) do
        with {:ok, map} <- Jason.decode(input) do
          new(map, id_generator)
        end
      end

      @impl Definition
      def schema do
        @schema.s()
      end

      defoverridable on_new: 2
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @impl Definition
      def migrate(arg), do: {:ok, arg}
    end
  end
end
