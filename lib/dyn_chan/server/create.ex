defmodule DynChan.Server.Create do
  require Logger
  use GenServer

  alias Nostrum.Api, as: Discord
  alias DynChan.{VoiceStates, Constants}
  alias DynChan.Server.{State, Channel}
  import DynChan.Server.Common

  # Discord channel types:
  @type_voice Constants.channel_type_voice()
  @type_category Constants.channel_type_category()

  def create_channel(name, %State{category_id: nil} = state) do
    cat_name = dynamic_category_name()

    result =
      Discord.create_guild_channel(state.id,
        name: cat_name,
        type: @type_category
      )

    case result do
      {:ok, channel} ->
        log(:info, state, "Created category: #{inspect(channel.name)}")
        state = %State{state | category_id: channel.id}
        create_channel(name, state)

      {:error, err} ->
        log(:error, state, "Failed to create category #{inspect(cat_name)}: #{inspect(err)}).")
        {{:error, err}, state}
    end
  end

  def create_channel(name, %State{category_id: cat_id} = state) when is_integer(cat_id) do
    result =
      Discord.create_guild_channel(state.id,
        name: name,
        type: @type_voice,
        parent_id: cat_id
      )

    case result do
      {:ok, channel} ->
        log(:info, state, "Created channel: #{inspect(channel.name)}")
        channels = [Channel.from_discord(channel) | state.channels]
        state = %State{state | channels: channels}
        {{:ok, channel}, state}

      {:error, err} ->
        log(:error, state, "Failed to create channel #{inspect(name)}: #{inspect(err)}).")
        {{:error, err}, state}
    end
  end
end
