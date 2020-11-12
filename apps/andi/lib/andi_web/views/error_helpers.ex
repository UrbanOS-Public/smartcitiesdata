defmodule AndiWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  alias AndiWeb.Views.DisplayNames

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, options \\ [])
  def error_tag(form, _, _) when not is_map(form), do: []

  def error_tag(form, field, options) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      translated = error |> interpret_error(field) |> translate_error()

      content_tag(:span, translated,
        class: "error-msg",
        id: "#{field}-error-msg",
        data: get_additional_content_tag_data(form, field, options)
      )
    end)
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

  defp interpret_error({message, opts}, field), do: {interpret_error_message(message, field), opts}

  defp interpret_error_message(message, :schema_sample), do: message
  defp interpret_error_message("is required", field), do: default_error_message(field)
  defp interpret_error_message(message, :format), do: "Error: " <> get_format_error_message(message)
  defp interpret_error_message(_message, :body), do: "Please enter valid JSON"

  defp interpret_error_message(message, field) when field in [:topLevelSelector, :cadence, :dataName, :license, :orgName],
    do: "Error: #{message}"

  defp interpret_error_message(_message, field) when field in [:sourceHeaders, :sourceQueryParams, :queryParams, :headers],
    do: "Please enter valid key(s)."

  defp interpret_error_message(_message, field), do: default_error_message(field)

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
