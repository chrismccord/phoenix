defmodule Mix.Tasks.Phoenix.Start do
  use Mix.Task

  @shortdoc "Starts application workers"
  @recursive true

  @moduledoc """
  Starts the router or a given worker. Defaults to `MyApp.Router`

      $ mix phoenix.start
      $ mix phoenix.start MyApp.AnotherRouter

  """
  def run([]) do
    Mix.Task.run "app.start", []
    if Mix.Phoenix.is_phoenix_app? do
      Mix.Phoenix.router.start
      no_halt
    end
  end

  def run([worker]) do
    Mix.Task.run "app.start", []
    remote_worker = Module.concat("Elixir", worker)
    remote_worker.start
    no_halt
  end

  defp no_halt do
    unless iex_running?, do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
