defmodule DynChan.ServerSupervisor do
  require Logger
  use DynamicSupervisor
  alias DynChan.Server

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def add(server_id) do
    DynamicSupervisor.start_child(__MODULE__, {Server, server_id})
  end

  def remove(server_id) do
    case ServerRegistry.whereis(server_id) do
      pid when is_pid(pid) -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      nil -> Logger.warn("ServerSupervisor: Can't remove #{server_id}: Not running.")
    end
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
