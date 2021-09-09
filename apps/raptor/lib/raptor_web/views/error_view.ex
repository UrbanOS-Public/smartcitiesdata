defmodule RaptorWeb.ErrorView do
  use RaptorWeb, :view

  def render("error.json", %{message: message}) do
    fill_json_template(message)
  end

  def render("error.csv", %{message: message}) do
    message
  end

  def render("404.html", %{message: message}) do
    message
  end

  def fill_json_template(message) do
    %{message: message}
  end

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    IO.inspect(template, label: "A")
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
