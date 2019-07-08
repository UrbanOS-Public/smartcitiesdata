require Logger

defmodule Reaper.S3Uploader do
  @moduledoc """
    Uploads a file to S3
  """
  alias ExAws.S3

  def upload(path, config) do
    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket_name(), file_path(config))
    |> ExAws.request()
  end

  defp bucket_name, do: "some_bucket"

  defp file_path(config), do: "#{config.orgName}/#{config.dataName}.#{config.sourceFormat}"
end
