defmodule AndiWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  alias Andi.InputSchemas.DisplayNames

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      translated = error |> interpret_error(field) |> translate_error()

      content_tag(:span, translated,
        class: "error-msg",
        id: "#{field}-error-msg",
        data: [phx_error_for: input_id(form, field)]
      )
    end)
  end

  @doc """
  Render an error_tag for the given input.

  Fixes the bug with non text-input fields not rendering the error message when clearing a valid value
  https://elixirforum.com/t/liveview-phx-change-attribute-does-not-emit-event-on-input-text/21280
  """
  def error_tag_live(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      translated = error |> interpret_error(field) |> translate_error()

      content_tag(:span, translated,
        class: "error-msg",
        id: "#{field}-error-msg"
      )
    end)
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

  defp interpret_error(error, field) do
    {_, opts} = error

    updated_message =
      case field do
        field when field in [:sourceHeaders, :sourceQueryParams] -> "Please enter a valid key(s)."
        _ -> "Please enter a valid #{get_downcased_display_name(field)}."
      end

    {updated_message, opts}
  end

  def get_downcased_display_name(field_key), do: field_key |> DisplayNames.get() |> String.downcase()
end
