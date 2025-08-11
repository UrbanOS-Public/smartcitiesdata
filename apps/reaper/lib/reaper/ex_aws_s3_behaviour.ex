defmodule Reaper.ExAwsS3Behaviour do
  @callback download_file(String.t(), String.t(), String.t()) :: any()
end