defmodule DynChan.ServerRegistry do
  # require Logger

  def child_spec(_) do
    Registry.child_spec(name: __MODULE__, keys: :unique)
  end

  def whereis(server_id) do
    case Registry.lookup(__MODULE__, server_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
end
