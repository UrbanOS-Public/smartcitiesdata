defmodule HttpHelper do
  def create_response(error_reason: error) do
    {:error, %HTTPoison.Error{id: nil, reason: error}}
  end

  def create_response(status_code: code) do
    {:ok, %HTTPoison.Response{status_code: code}}
  end

  def create_response(body: body) do
    {:ok, %HTTPoison.Response{body: Poison.encode!(body), status_code: 200}}
  end
end
