defmodule DynChan.ServerSupervisor do
  require Logger
  use Supervisor
  alias DynChan.Server

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def add(server_id) do
    spec =
      Server.child_spec(server_id)
      |> Map.put(:id, server_id)

    case Supervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> pid
      {:error, error} -> Logger.error("Failed to launch server: #{inspect(error)}")
    end
  end

  def remove(server_id) do
    Supervisor.terminate_child(__MODULE__, server_id)
    Supervisor.delete_child(__MODULE__, server_id)
  end

  def poke(server_id) do
    case whereis(server_id) do
      nil -> Logger.warn("Failed to poke server #{inspect(server_id)}: Not running.")
      pid when is_pid(pid) -> Server.poke(pid)
    end
  end

  defp whereis(server_id) do
    Supervisor.which_children(__MODULE__)
    |> Enum.find_value(fn {id, pid, _, _} -> id == server_id && pid end)
  end

  @impl true
  def init(_) do
    Supervisor.init([], strategy: :one_for_one)
  end
end
