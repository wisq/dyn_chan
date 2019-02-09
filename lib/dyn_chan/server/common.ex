defmodule DynChan.Server.Common do
  require Logger

  def dynamic_category_name do
    Application.get_env(:dyn_chan, :category, "Dynamic Channels")
  end

  def log(level, state, message) do
    Logger.log(level, ["#{inspect(state.name)}: ", message])
  end
end
