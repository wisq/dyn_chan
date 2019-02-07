defmodule DynChanTest do
  use ExUnit.Case
  doctest DynChan

  test "greets the world" do
    assert DynChan.hello() == :world
  end
end
