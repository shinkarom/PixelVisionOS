--
-- Copyright (c) 2017, Jesse Freeman. All rights reserved.
--
-- Licensed under the Microsoft Public License (MS-PL) License.
-- See LICENSE file in the project root for full license information.
--
-- Contributors
-- --------------------------------------------------------
-- This is the official list of Pixel Vision 8 contributors:
--
-- Jesse Freeman - @JesseFreeman
-- Christer Kaitila - @McFunkypants
-- Pedro Medeiros - @saint11
-- Shawn Rakowski - @shwany
--

function Init()

  -- display instruction text for playing thesound
  DrawText("Music Demo", 1, 1, DrawMode.Tile, "large", 15)
  DrawText("Click anywhere to play!", 1, 4, DrawMode.Tile, "large", 15)

  --apiBridge:LoadSong(0)
end

function Update()
  -- get if the mouse is down
  local mouseDown = MouseButton(0, InputState.Released)

  -- if mouse is down, play the first sound sfx
  if(mouseDown == true) then
    -- play the first sound id in the first channel
    PlayPatterns({0, 1, 2, 3, 4}, true)
  end

  local patternID = 0
  local currentBeat = 0
  local totalNotes = 32

  DrawText("Pattern ID " .. patternID .. "/5" .." Beat " .. currentBeat .. "/" .. totalNotes, 8, 256 - 32, DrawMode.Sprite, "large", 15)

end

function Draw()
  Clear()
  DrawTilemap()
end
