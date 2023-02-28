defmodule Andi.InputSchemas.Ingestions.ExtractAuthStep do
  @moduledoc false
  use Ecto.Schema

  alias Andi.InputSchemas.Ingestions.ExtractHeader
  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:body, :string)
    field(:url, :string)
    field(:destination, :string)
    field(:encode_method, :string)
    field(:cacheTtl, :integer, default: 900_000)
    field(:path, {:array, :string})
    embeds_many(:headers, ExtractHeader, on_replace: :delete)
  end

  use Accessible

  @cast_fields [:destination, :encode_method, :path, :cacheTtl, :url, :body]
  @required_fields [:destination, :url, :path, :cacheTtl]

  def get_module(), do: %__MODULE__{}

  def changeset(extract_step, changes) do
    changes_with_id =
      StructTools.ensure_id(extract_step, changes)
      |> AtomicMap.convert(safe: false, underscore: false)
      |> format()

    extract_step
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [[]])
    |> Changeset.cast_embed(:headers, with: &ExtractHeader.changeset/2)
  end

  def validate(extract_step_changeset) do
    data_as_changes =
      extract_step_changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()
      |> format()

    validated_extract_step_changeset =
      extract_step_changeset
      |> Map.replace(:errors, [])
      |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [[]], force_changes: true)
      |> Changeset.cast_embed(:headers, with: &ExtractHeader.changeset/2)
      |> Changeset.validate_required(@required_fields, message: "is required")
      |> Changeset.validate_format(:destination, ~r/^[[:alpha:]_]+$/)
      |> validate_body_format()
      |> validate_path()
      |> validate_headers()

    if is_nil(Map.get(validated_extract_step_changeset, :action, nil)) do
      Map.put(validated_extract_step_changeset, :action, :display_errors)
    else
      validated_extract_step_changeset
    end
  end

  def preload(struct), do: StructTools.preload(struct, [:headers])

  defp format(changes) do
    changes
    |> format_cache_ttl()
    |> format_path()
  end

  defp format_cache_ttl(%{cacheTtl: form_cache_ttl} = changes) when is_binary(form_cache_ttl) do
    case String.match?(form_cache_ttl, ~r/^[[:digit:]]+$/) do
      true -> Map.put(changes, :cacheTtl, String.to_integer(form_cache_ttl) * 60_000)
      false -> changes
    end
  end

  defp format_cache_ttl(%{cacheTtl: nil} = changes), do: changes
  defp format_cache_ttl(changes), do: changes

  defp format_path(%{path: nil} = changes), do: changes
  defp format_path(%{path: path} = changes) when is_binary(path), do: Map.put(changes, :path, String.split(path, "."))
  defp format_path(changes), do: changes

  defp validate_body_format(%{changes: %{body: body}} = changeset) when body in ["", nil], do: changeset

  defp validate_body_format(%{changes: %{body: body}} = changeset) do
    case Jason.decode(body) do
      {:ok, _} -> changeset
      {:error, _} -> Changeset.add_error(changeset, :body, "could not parse json", validation: :format)
    end
  end

  defp validate_body_format(changeset), do: changeset

  # defp validate_path(%{changes: %{path: []}} = changeset), do: Changeset.add_error(changeset, :path, "is required")

  defp validate_path(%{changes: %{path: path}} = changeset) do
    case Enum.any?(path, fn path_field -> path_field in ["", nil] end) do
      true -> Changeset.add_error(changeset, :path, "path fields cannot be empty")
      false -> changeset
    end
  end

  defp validate_path(changeset), do: changeset

  defp validate_headers(changeset) do
    headers =
      case Changeset.fetch_field(changeset, :headers) do
        {_, headers} -> headers
        :error -> []
      end

    Enum.reduce(headers, changeset, fn header, acc ->
      validated_header_changeset =
        ExtractHeader.changeset(header, %{})
        |> ExtractHeader.validate()

      Enum.reduce(validated_header_changeset.errors, acc, fn {_key, {message, _}}, error_acc ->
        Changeset.add_error(error_acc, :headers, message)
      end)
    end)
  end
end
