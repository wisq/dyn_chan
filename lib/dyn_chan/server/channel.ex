defmodule DynChan.Server.Channel do
  alias __MODULE__

  @enforce_keys [:id, :name]
  defstruct(
    id: nil,
    name: nil,
    timeout: nil
  )

  def from_discord(%{id: id, name: name}) do
    %Channel{id: id, name: name}
  end

  def update(%Channel{id: id} = channel, active) do
    if id in active do
      set_active(channel)
    else
      set_inactive(channel)
    end
  end

  def set_active(%Channel{} = channel) do
    %Channel{channel | timeout: nil}
  end

  def set_inactive(%Channel{timeout: nil} = channel) do
    %Channel{channel | timeout: idle_timeout() |> in_future()}
  end

  def set_inactive(%Channel{timeout: %{zone_abbr: "UTC"}} = channel) do
    channel
  end

  defp idle_timeout, do: Application.get_env(:dyn_chan, :idle_timeout, 300)
  defp in_future(secs), do: DateTime.utc_now() |> DateTime.add(secs, :second)

  def earliest_timeout(channels) do
    channels
    |> Enum.filter(fn c -> !is_nil(c.timeout) end)
    |> min_sortable_timeout()
  end

  defp min_sortable_timeout([]), do: nil
  defp min_sortable_timeout(list), do: Enum.min_by(list, &sortable_timeout/1)

  defp sortable_timeout(%Channel{timeout: timeout}) do
    DateTime.to_unix(timeout, :native)
  end
end
