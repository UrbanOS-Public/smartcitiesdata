defmodule AndiWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.InputSchemas.SubmissionMetadataFormSchema
  alias AndiWeb.Views.DisplayNames

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, options \\ [])
  def error_tag(form, _, _) when not is_map(form), do: []

  def error_tag(form, field, options) do
    form.errors
    |> Map.new()
    |> Map.get(field)
    |> generate_error_tag(field, form, options)
  end

  defp generate_error_tag(nil, _, _, _), do: nil

  defp generate_error_tag(error, field, form, options) do
    %{data: %form_type{}} = form
    translated = error |> interpret_error(field, form_type) |> translate_error()

    content_tag(:span, translated,
      class: "error-msg",
      id: "#{field}-error-msg",
      data: get_additional_content_tag_data(form, field, options)
    )
  end

  def error_tag_with_label(form, field, label, options \\ [])
  def error_tag_with_label(form, _, _, _) when not is_map(form), do: []

  def error_tag_with_label(form, field, label, options) do
    form.errors
    |> Map.new()
    |> Map.get(field)
    |> generate_error_tag_with_label(field, form, label, options)
  end

  defp generate_error_tag_with_label(nil, _, _, _, _), do: nil

  defp generate_error_tag_with_label(error, field, form, label, options) do
    %{data: %form_type{}} = form

    translated =
      error
      |> interpret_error_with_label(field, form_type, label)
      |> translate_error()

    content_tag(:span, translated,
      class: "error-msg",
      id: "#{field}-error-msg",
      data: get_additional_content_tag_data(form, field, options)
    )
  end

  # Fixes the bug with non text-input fields not rendering the error message when clearing a valid value
  # https://elixirforum.com/t/liveview-phx-change-attribute-does-not-emit-event-on-input-text/21280
  defp get_additional_content_tag_data(form, field, options) do
    bind_to_input = Keyword.get(options, :bind_to_input, true)
    if bind_to_input, do: [phx_error_for: input_id(form, field)], else: []
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(AndiWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(AndiWeb.Gettext, "errors", msg, opts)
    end
  end

  defp interpret_error({message, opts}, field, form_type), do: {interpret_error_message(message, field, form_type), opts}

  defp interpret_error_message(_message, :description, SubmissionMetadataFormSchema),
    do:
      "Please describe your dataset. What information does it contain? Where, when, and how was the data collected? Which organization produced the dataset, if applicable?"

  defp interpret_error_message(_message, :sourceFormat, SubmissionMetadataFormSchema),
    do:
      "Please enter a valid source format. Your file should either be in CSV or JSON format. If your dataset file exists in another format, please convert it to the correct format before proceeding."

  defp interpret_error_message(_message, :contactName, SubmissionMetadataFormSchema),
    do: "Please enter a valid maintainer name. Who produces and/or updates this dataset? If you are the maintainer, enter your name."

  defp interpret_error_message(_message, :name, DataDictionary) do
    "Please enter a valid name. Schema fields cannot contain control characters."
  end

  defp interpret_error_message(_message, :schema, _), do: "Please add a field to continue"

  defp interpret_error_message(message, :schema_sample, _), do: message
  defp interpret_error_message("is required", :targetDataset, _), do: default_error_message(:targetDataset)
  defp interpret_error_message(message, :targetDataset, _), do: message
  defp interpret_error_message(message, :datasetLink, _), do: message
  defp interpret_error_message("is required", field, _), do: default_error_message(field)
  defp interpret_error_message(message, :format, _), do: "Error: " <> get_format_error_message(message)
  defp interpret_error_message(_message, :body, _), do: "Please enter valid JSON"

  defp interpret_error_message(message, field, _) when field in [:topLevelSelector, :cadence, :dataName, :license, :orgName],
    do: "Error: #{message}"

  defp interpret_error_message(_message, field, _) when field in [:sourceHeaders, :sourceQueryParams, :queryParams, :headers],
    do: "Please enter valid key(s)."

  defp interpret_error_message(_message, field, _), do: default_error_message(field)

  defp interpret_error_with_label({_message, opts}, _field, form_type, label),
    do: {interpret_error_message_with_label(label, form_type), opts}

  defp interpret_error_message_with_label(label, Transformation) do
    "Please enter a valid #{String.downcase(label)}"
  end

  defp default_error_message(field), do: "Please enter a valid #{get_downcased_display_name(field)}."

  def get_downcased_display_name(field_key), do: field_key |> DisplayNames.get() |> String.downcase()

  defp get_format_error_message("Format string cannot be empty" <> _), do: "format is required"

  defp get_format_error_message("There were no formatting directives in the provided string" <> _),
    do: "format must adhere to directive format. Refer to the link above for help"

  defp get_format_error_message("Invalid format string" <> _),
    do: "format must adhere to directive format. Refer to the link above for help"

  defp get_format_error_message("Expected at least one parser to succeed" <> _), do: "failed to parse"
  defp get_format_error_message(message), do: message
end
