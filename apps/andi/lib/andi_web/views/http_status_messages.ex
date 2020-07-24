defmodule AndiWeb.Views.HttpStatusDescriptions do
  @moduledoc """
  View translations from status code to descriptive text and help link.
  """

  import Plug.Conn.Status,
    only: [
      reason_phrase: 1
    ]

  @url_200 "https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#2xx_Success"
  @url_400 "https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#4xx_Client_errors"
  @url_500 "https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#5xx_Client_errors"
  @url_other "https://en.wikipedia.org/wiki/List_of_HTTP_status_codes"

  @code_descriptions [
    # Ex.MaxLen "the target resource resides temporarily under a different URI"
    {~r/^[2-3][0-9][0-9]$/, "request was a success", @url_200},
    {~r/^400$/, "request is not in an expected form", @url_400},
    {~r/^401$/, "resource requires authentication", @url_400},
    {~r/^402$/, "resource requires payment", @url_400},
    {~r/^403$/, "request is not allowed by the server", @url_400},
    {~r/^404$/, "resource is not on the server", @url_400},
    {~r/^405$/, "request method is not supported", @url_400},
    {~r/^406$/, "resource is not in an acceptable format", @url_400},
    {~r/^407$/, "resource needs proxy authentication", @url_400},
    {~r/^408$/, "request took too long to get to the server", @url_400},
    {~r/^409$/, "resource is in a conflicted state", @url_400},
    {~r/^410$/, "resource is now gone, but was available", @url_400},
    {~r/^411$/, "request needs the Content-Length header", @url_400},
    {~r/^412$/, "request has a condition server can't meet", @url_400},
    {~r/^413$/, "request body is too large for the server", @url_400},
    {~r/^414$/, "request uri is too large for the server", @url_400},
    {~r/^415$/, "request has a content type that server won't accept", @url_400},
    {~r/^416$/, "request wants a resource part that the server can't provide", @url_400},
    {~r/^417$/, "request has expect header that the server can't fulfill", @url_400},
    {~r/^418$/, "response is an April Fools joke", @url_400},
    {~r/^421$/, "request is directed at an incapable server", @url_400},
    {~r/^422$/, "request has instructions that the server can't process", @url_400},
    {~r/^423$/, "resource is locked", @url_400},
    {~r/^424$/, "request depends on another request that failed", @url_400},
    {~r/^425$/, "request has an Early-Data header that is too risky", @url_400},
    {~r/^426$/, "resource needs a client upgrade first", @url_400},
    {~r/^428$/, "request needs a condition header", @url_400},
    {~r/^429$/, "request has been rate-limited", @url_400},
    {~r/^431$/, "request header(s) is too large for the server", @url_400},
    {~r/^451$/, "resource is inaccessible for legal reasons", @url_400},
    {~r/^500$/, "server experienced an unexpected error", @url_500},
    {~r/^501$/, "server does not implement the request method", @url_500},
    {~r/^502$/, "server can't proxy the request", @url_500},
    {~r/^503$/, "server temporarily can't handle the request", @url_500},
    {~r/^504$/, "server timed out while proxying the request", @url_500},
    {~r/^505$/, "server does not support HTTP version in request", @url_500},
    {~r/^506$/, "server can't negotiate content type", @url_500},
    {~r/^507$/, "server does not have enough storage for request", @url_500},
    {~r/^508$/, "server would encounter an infinite loop during request", @url_500},
    {~r/^510$/, "server requires request to be extended", @url_500},
    {~r/^511$/, "server requires network authentication", @url_500},
    {~r/^.*$/, "response contains an unknown status code", @url_other}
  ]

  def get(code) do
    code_as_string = to_string(code)

    {_code_regex, code_description, code_url} =
      Enum.find(@code_descriptions, fn {code_regex, code_description, code_url} ->
        Regex.match?(code_regex, code_as_string)
      end)

    code_reason = code_reason(code)
    code_link = code_link(code_url)

    "The #{code_as_string} (#{code_reason}) status code indicates that the #{code_description}. #{code_link}"
  end

  defp code_reason(code) do
    reason_phrase(code)
  rescue
    _ -> "Unknown reason"
  end

  defp code_link(url) do
    "<a href='#{url}' target='_blank'>More</a>"
  end
end
