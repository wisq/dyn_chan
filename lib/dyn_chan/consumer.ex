defmodule DynChan.Consumer do
  require Logger
  use Nostrum.Consumer

  alias DynChan.{
    VoiceStates,
    ServerSupervisor,
    Server,
    Messages
  }

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:GUILD_AVAILABLE, {guild}, _ws_state}) do
    VoiceStates.add_server(guild.id, guild.voice_states)
    ServerSupervisor.add(guild.id)
  end

  def handle_event({:GUILD_UNAVAILABLE, {guild}, _ws_state}) do
    ServerSupervisor.remove(guild.id)
  end

  def handle_event({:VOICE_STATE_UPDATE, {voice_state}, _ws_state}) do
    VoiceStates.update_state(voice_state.guild_id, voice_state)
    Server.poke(voice_state.guild_id)
  end

  def handle_event({:MESSAGE_CREATE, {msg}, _ws_state}) do
    Messages.message(msg.content, msg)
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event({type, _data, _ws_state}) do
    Logger.debug("Consumer received unknown event type: #{type}")
    :noop
  end
end
