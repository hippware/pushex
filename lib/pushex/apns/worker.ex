defmodule Pushex.APNS.Worker do
  use GenServer

  def start_link(app) do
    {:ok, pid} = result = GenServer.start_link(__MODULE__, app)
    GenServer.cast(pid, :connect)
    result
  end

  def init(%Pushex.APNS.App{} = app) do
    {:ok, %{app: app}}
  end

  def handle_cast(:connect, %{app: app} = state) do
    validate_authentication(app)
    ssl_options = Pushex.APNS.App.ssl_options(app)
    {:ok, pid} = :h2_client.start_link(config(:protocol), endpoint(app), config(:port), ssl_options)
    new_state =
      state
      |> Map.put(:conn_pid, pid)
      |> Map.put(:use_jwt, Pushex.APNS.App.use_jwt?(app))
    {:noreply, new_state}
  end

  defp validate_authentication(app) do
    unless Pushex.APNS.App.can_authenticate?(app) do
      raise "missing authentication information in #{app}"
    end
  end

  defp endpoint(app) do
    app |> endpoint_key() |> config() |> String.to_charlist()
  end

  defp endpoint_key(%Pushex.APNS.App{env: :prod}), do: :prod_endpoint
  defp endpoint_key(%Pushex.APNS.App{env: :dev}), do: :dev_endpoint

  defp config(), do: Application.get_env(:pushex, :apns)
  defp config(key), do: config()[key]
end
