defmodule Andi.InputSchemas.Ingestions.ExtractHttpStep do
  @moduledoc false
  use Ecto.Schema

  alias Andi.InputSchemas.Ingestions.ExtractQueryParam
  alias Andi.InputSchemas.Ingestions.ExtractHeader
  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:body, :string)
    field(:action, :string, default: "GET")
    field(:protocol, {:array, :string})
    field(:url, :string)
    embeds_many(:headers, ExtractHeader, on_replace: :delete)
    embeds_many(:queryParams, ExtractQueryParam, on_replace: :delete)
  end

  use Accessible

  @cast_fields [:action, :protocol, :url, :body]
  @required_fields [:action, :url]

  def get_module(), do: %__MODULE__{}

  def changeset(extract_step, changes) do
    changes_with_id =
      StructTools.ensure_id(extract_step, changes)
      |> AtomicMap.convert(safe: false, underscore: false)
      |> format()

    extract_step
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [], force_changes: true)
    |> Changeset.cast_embed(:headers, with: &ExtractHeader.changeset/2)
    |> Changeset.cast_embed(:queryParams, with: &ExtractQueryParam.changeset/2)
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
      |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [], force_changes: true)
      |> Changeset.cast_embed(:headers, with: &ExtractHeader.changeset/2)
      |> Changeset.cast_embed(:queryParams, with: &ExtractQueryParam.changeset/2)
      |> validate_body_format()
      |> validate_url()
      |> Changeset.validate_required(@required_fields, message: "is required")
      |> validate_key_value_set(:headers)
      |> validate_key_value_set(:queryParams)

    if is_nil(Map.get(validated_extract_step_changeset, :action, nil)) do
      Map.put(validated_extract_step_changeset, :action, :display_errors)
    else
      validated_extract_step_changeset
    end
  end

  def preload(struct), do: StructTools.preload(struct, [:headers, :queryParams])

  defp format(changes) do
    changes
    |> format_url()
  end

  defp format_url(%{url: url, queryParams: %{} = query_params} = changes) do
    query_param_array =
      Enum.reduce(Map.to_list(query_params), [], fn {_index, query_param}, acc ->
        acc ++ [%{key: query_param.key, value: query_param.value}]
      end)

    new_url = Andi.URI.update_url_with_params(url, query_param_array)
    Map.put(changes, :url, new_url)
  end

  defp format_url(%{url: url, queryParams: query_params} = changes) do
    new_url = Andi.URI.update_url_with_params(url, query_params)
    Map.put(changes, :url, new_url)
  end

  defp format_url(changes), do: changes

  defp validate_key_value_set(changeset, field) do
    key_value_set = Ecto.Changeset.get_field(changeset, field)

    case key_value_has_invalid_key?(key_value_set) do
      true -> Changeset.add_error(changeset, field, "has invalid format", validation: :format)
      false -> changeset
    end
  end

  defp validate_url(%{changes: %{url: url}} = changeset) when url in ["", nil], do: changeset

  defp validate_url(%{changes: %{url: url}} = changeset) do
    with uri <- Andi.URI.parse(url),
         {:error, _} <- Andi.URI.validate_uri(uri) do
      Changeset.add_error(changeset, :url, "invalid url")
    else
      _ -> changeset
    end
  end

  defp validate_url(changeset), do: changeset

  defp validate_body_format(%{changes: %{body: body}} = changeset) when body in ["", nil], do: changeset

  defp validate_body_format(%{changes: %{body: body}} = changeset) do
    case Jason.decode(body) do
      {:ok, _} -> changeset
      {:error, _} -> Changeset.add_error(changeset, :body, "could not parse json", validation: :format)
    end
  end

  defp validate_body_format(changeset), do: changeset

  defp key_value_has_invalid_key?(nil), do: false

  defp key_value_has_invalid_key?(key_value_set) do
    Enum.any?(key_value_set, fn key_value -> key_value.key in [nil, ""] end)
  end
end
