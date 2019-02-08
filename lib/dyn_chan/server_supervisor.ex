defmodule DynChan.ServerSupervisor do
  require Logger
  use DynamicSupervisor

  alias DynChan.{Server, ServerRegistry}

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def add(server_id) do
    DynamicSupervisor.start_child(__MODULE__, {Server, server_id})
  end

  def remove(server_id) do
    case ServerRegistry.whereis(server_id) do
      pid when is_pid(pid) ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      nil ->
        {:error, :not_found}
    end
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
