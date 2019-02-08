defmodule DynChan do
  require Logger
  use Application

  @children [
    DynChan.VoiceStates,
    DynChan.ServerRegistry,
    DynChan.ServerSupervisor,
    DynChan.Consumer
  ]

  def start(_type, _args) do
    Logger.info("DynChan starting.")

    Supervisor.start_link(
      @children,
      strategy: :one_for_one,
      name: DynChan.Supervisor
    )
  end
end
