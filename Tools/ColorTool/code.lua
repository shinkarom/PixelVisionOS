--[[
	Pixel Vision 8 - Display Tool
	Copyright (C) 2017, Pixel Vision 8 (http://pixelvision8.com)
	Created by Jesse Freeman (@jessefreeman)

	Please do not copy and distribute verbatim copies
	of this license document, but modifications without
	distributing is allowed.
]]--

-- API Bridge
LoadScript("sb-sprites")
LoadScript("pixel-vision-os-v2")
LoadScript("pixel-vision-os-color-picker-v2")
LoadScript("pixel-vision-os-sprite-picker-v2")
LoadScript("color-editor-modal")
LoadScript("code-color-editor-modal")

local toolName = "Color Tool"
local editColorModal = nil
local colorOffset = 0
-- local systemColorsPerPage = 64
local success = false
local emptyColorID = -1
local dragTime = 0
local dragDelay = .5

-- Default palette options
-- local pixelVisionOS.paletteColorsPerPage = 0
local maxPalettePages = 8
local paletteOffset = 0
local paletteColorPages = 0
local spriteEditorPath = ""
local spritesInvalid = false
-- local pixelVisionOS.totalPaletteColors = 0
local totalPalettePages = 0
local debugMode = false
local showBGIcon = false
local BGIconX = 0
local BGIconY = 0
-- local pixelVisionOS.paletteColors = {}
-- local maxColorsPerPalette = 16

local SaveShortcut, AddShortcut, EditShortcut, ClearShortcut, DeleteShortcut, BGShortcut, UndoShortcut, RedoShortcut, CopyShortcut, PasteShortcut = 5, 7, 8, 9, 10, 11, 13, 14, 15, 16

-- Create some Constants for the different color modes
local NoColorMode, SystemColorMode, PaletteMode = 0, 1, 2

-- The default selected mode is NoColorMode
local selectionMode = NoColorMode

function InvalidateData()

  -- Only everything if it needs to be
  if(invalid == true)then
    return
  end

  pixelVisionOS:ChangeTitle(toolTitle .."*", "toolbariconfile")

  invalid = true

  pixelVisionOS:EnableMenuItem(SaveShortcut, true)

end

function ResetDataValidation()

  -- Only everything if it needs to be
  if(invalid == false)then
    return
  end

  pixelVisionOS:ChangeTitle(toolTitle, "toolbariconfile")
  invalid = false

  pixelVisionOS:EnableMenuItem(SaveShortcut, false)

end

function Init()

  BackgroundColor(22)

  -- Disable the back key in this tool
  EnableBackKey(false)



  -- Create an instance of the Pixel Vision OS
  pixelVisionOS = PixelVisionOS:Init()

  -- Get a reference to the Editor UI
  editorUI = pixelVisionOS.editorUI

  -- Reset the undo history so it's ready for the tool
  pixelVisionOS:ResetUndoHistory()

  rootDirectory = ReadMetaData("directory", nil)

  -- TODO For testing, we need a path
  -- rootDirectory = "/Workspace/Games/GGSystem/"
  -- rootDirectory = "/Workspace/Games/JumpNShootMan/"
  -- rootDirectory = "/Workspace/Games/ZeldaIIPalaceAnimation/"
  -- rootDirectory = "/Workspace/Games/ReaperBoyLD42Disk2/"

  if(rootDirectory ~= nil) then

    -- Load only the game data we really need
    success = gameEditor.Load(rootDirectory, {SaveFlags.System, SaveFlags.Meta, SaveFlags.Colors, SaveFlags.ColorMap, SaveFlags.Sprites})

  end

  -- If data loaded activate the tool
  if(success == true) then

    -- Get a list of all the editors
    local editorMapping = FindEditors()

    -- Find the json editor
    spriteEditorPath = editorMapping["sprites"]

    -- The first thing we need to do is rebuild the tool's color table to include the game's system and game colors.
    pixelVisionOS:ImportColorsFromGame()

    editColorModal = EditColorModal:Init(editorUI, pixelVisionOS.maskColor)

    -- spriteEditorPath = ReadMetaData("RootPath", "/") .."SpriteTool/"
    --
    -- -- Get the path to the editor from the bios
    -- local bioPath = ReadBiosData("SpriteEditor")
    --
    -- if(biosPath ~= nil) then
    --   spriteEditorPath = bioPath
    -- end

    -- print("Sprite Editor Path", spriteEditorPath)

    local menuOptions = 
    {
      -- About ID 1
      {name = "About", action = function() pixelVisionOS:ShowAboutModal(toolName) end, toolTip = "Learn about PV8."},
      {divider = true},
      --
      -- {name = "Toggle Mask", action = OnToggleMask, enabled = false, toolTip = "Toggle between the background and mask color."}, -- Reset all the values
      {name = "Toggle Mode", action = function() TogglePaletteMode(not usePalettes) end, enabled = true, toolTip = "Toggle between palette and direct color mode."}, -- Reset all the values
      {name = "Edit Sprites", enabled = spriteEditorPath ~= nil, action = OnEditSprites, toolTip = "Open the sprite editor."},
      -- Reset all the values
      {name = "Save", action = OnSave, enabled = false, key = Keys.S, toolTip = "Save changes made to the colors.png file."}, -- Reset all the values
      {divider = true},
      {name = "Add", action = OnAdd, enabled = false, toolTip = "Add a new color to the currently selected picker."},
      {name = "Edit", action = OnConfig, enabled = false, key = Keys.E, toolTip = "Edit the currently selected color."},
      {name = "Clear", action = OnClear, enabled = false, toolTip = "Clear the currently selected color."},
      {name = "Delete", action = OnDelete, enabled = false, toolTip = "Remove the currently selected color."},
      {name = "Set BG Color", action = OnSetBGColor, enabled = false, toolTip = "Set the current color as the background."}, -- Reset all the values
      {divider = true},
      {name = "Undo", action = OnRevert, enabled = false, key = Keys.Z, toolTip = "Undo the last action."}, -- Reset all the values
      {name = "Redo", action = OnRevert, enabled = false, key = Keys.X, toolTip = "Redo the last undo."}, -- Reset all the values
      {name = "Copy", action = OnCopy, enabled = false, key = Keys.C, toolTip = "Copy the currently selected sound."}, -- Reset all the values
      {name = "Paste", action = OnPaste, enabled = false, key = Keys.V, toolTip = "Paste the last copied sound."}, -- Reset all the values

      {divider = true},
      {name = "Quit", key = Keys.Q, action = OnQuit, toolTip = "Quit the current game."}, -- Quit the current game
    }

    pixelVisionOS:CreateTitleBarMenu(menuOptions, "See menu options for this tool.")

    -- Split the root directory path
    local pathSplit = string.split(rootDirectory, "/")

    -- save the title with file path
    toolTitle = pathSplit[#pathSplit] .. "/colors.png"

    -- TODO this is debug code and can be removed when things are working

    if(debugMode == true) then
      colorMemoryCanvas = NewCanvas(8, TotalColors() / 8)

      print("Total Colors", pixelVisionOS.totalColors)
      local pixels = {}
      for i = 1, TotalColors() do
        local index = i - 1
        table.insert(pixels, index)
      end

      colorMemoryCanvas:SetPixels(pixels)
    end


    -- We need to modify the color selection sprite so we start with a reference to it
    local selectionPixelData = colorselection

    -- Now we need to create the item picker over sprite by using the color selection spriteIDs and changing the color offset
    _G["itempickerover"] = {spriteIDs = colorselection.spriteIDs, width = colorselection.width, colorOffset = 28}

    -- Next we need to create the item picker selected up sprite by using the color selection spriteIDs and changing the color offset
    _G["itempickerselectedup"] = {spriteIDs = colorselection.spriteIDs, width = colorselection.width, colorOffset = (_G["itempickerover"].colorOffset + 4)}


    -- Create an input field for the currently selected color ID
    colorIDInputData = editorUI:CreateInputField({x = 152, y = 208, w = 24}, "0", "The ID of the currently selected color.", "number")

    -- The minimum value is always 0 and we'll set the maximum value based on which color picker is currently selected
    colorIDInputData.min = 0

    -- Map the on action to the ChangeColorID method
    colorIDInputData.onAction = ChangeColorID

    -- Create a hex color input field
    colorHexInputData = editorUI:CreateInputField({x = 200, y = 208, w = 48}, "FF00FF", "Hex value of the selected color.", "hex")

    -- Call the UpdateHexColor function when a change is made
    colorHexInputData.onAction = UpdateHexColor

    -- Override string capture and only send uppercase characters to the field
    colorHexInputData.captureInput = function()
      return string.upper(InputString())
    end

    -- It's time to calculate the total number of system and palette colors

    -- Get the palette mode
    usePalettes = pixelVisionOS.paletteMode
    --

    -- Read the palette mode flag from the meta data
    -- local paletteMode =



    -- Calculate the total system color pages, there are 4 in direct color mode (64 per page for 256 total) or 2 in palette mode (64 per page for 128 total)
    -- local maxSystemPages = 4--gameEditor:ColorPages()

    -- math.ceil(pixelVisionOS.totalSystemColors / pixelVisionOS.systemColorsPerPage)

    -- Create the system color picker
    systemColorPickerData = pixelVisionOS:CreateColorPicker(
      {x = 8, y = 32, w = 128, h = 128}, -- Rect
      {x = 16, y = 16}, -- Tile size
      pixelVisionOS.totalSystemColors, -- Total colors, plus 1 for empty transparancy color
      pixelVisionOS.systemColorsPerPage, -- total per page
      4, -- max pages
      pixelVisionOS.colorOffset, -- Color offset to start reading from
      "itempicker", -- Selection sprite name
      "Select system color ", -- Tool tip
      false, -- Modify pages
      true, -- Enable dragging,
      true -- drag between pages
    )

    systemColorPickerData.onPageAction = function(value)

      local bgColor = gameEditor:BackgroundColor()
      local bgPageID = math.ceil((bgColor + 1) / 64)

      showBGIcon = bgPageID == value

      UpdateBGIconPosition(bgColor)

    end

    -- systemColorPickerData.onStartDrag = function()
    --
    --
    --
    -- end

    -- Create a function to handle what happens when a color is dropped onto the system color picker
    systemColorPickerData.onDropTarget = OnSystemColorDropTarget

    -- Manage what happens when a color is selected
    systemColorPickerData.onColorPress = function(value)

      -- Change the focus of the current color picker
      ForcePickerFocus(systemColorPickerData)

      -- Call the OnSelectSystemColor method to update the fields
      OnSelectSystemColor(value)

    end

    -- Create the palette color picker
    paletteColorPickerData = pixelVisionOS:CreateColorPicker(
      {x = 8, y = 184, w = 128, h = 32},
      {x = 16, y = 16},
      pixelVisionOS.totalPaletteColors,
      16,
      8,
      pixelVisionOS.colorOffset + pixelVisionOS.totalPaletteColors,
      "itempicker",
      "Select palette color ",
      false,
      true
    )

    -- Force the palette picker to only display the total colors per sprite
    paletteColorPickerData.visiblePerPage = pixelVisionOS.paletteColorsPerPage

    paletteColorPickerData.onColorPress = function(value)
      ForcePickerFocus(paletteColorPickerData)

      OnSelectPaletteColor(value)

      -- StartPickerDrag(systemColorPickerData.picker)
    end

    -- paletteColorPickerData.onAddPage = AddPalettePage
    -- paletteColorPickerData.onRemovePage = RemovePalettePage

    paletteColorPickerData.onDropTarget = OnPalettePickerDrop

    -- Copy over all the palette colors to memory if we are in palette mode
    -- if(usePalettes) then
    --   pixelVisionOS:CopyPaletteColorsToMemory()
    -- end

    spritePickerData = pixelVisionOS:CreateSpritePicker(
      {x = 152, y = 32, w = 96, h = 128 },
      {x = 8, y = 8},
      gameEditor:TotalSprites(),
      192,
      10,
      pixelVisionOS.colorOffset + pixelVisionOS.totalPaletteColors,
      "spritepicker",
      "Pick a sprite"
    )

    -- The sprite picker shouldn't be selectable on this screen but you can still change pages
    pixelVisionOS:EnableSpritePicker(spritePickerData, false, true)

    --
    -- Wire up the picker to change the color offset of the sprite picker
    paletteColorPickerData.onPageAction = function(value)

      -- TODO need to update the sprite page with new color offset

      spritePickerData.colorOffset = pixelVisionOS.colorOffset + pixelVisionOS.totalPaletteColors + ((value - 1) * 16)

      pixelVisionOS:RedrawSpritePickerPage(spritePickerData)

    end

    pixelVisionOS:SelectColorPage(systemColorPickerData, 1)

    pixelVisionOS:SelectSpritePickerPage(spritePickerData, 1)

    RedrawPaletteUI()

    if(usePalettes == true) then
      pixelVisionOS:SelectColorPage(paletteColorPickerData, 1)
    end

    -- Reset the validation to update the title and set the validation flag correctly for any changes
    ResetDataValidation()

    -- Set the focus mode to none
    ForcePickerFocus()

  else

    -- Patch background when loading fails

    -- Left panel
    DrawRect(8, 32, 128, 128, 0, DrawMode.TilemapCache)

    DrawRect(152, 32, 96, 128, 0, DrawMode.TilemapCache)

    DrawRect(152, 208, 24, 8, 0, DrawMode.TilemapCache)

    DrawRect(200, 208, 48, 8, 0, DrawMode.TilemapCache)

    DrawRect(136, 164, 3, 9, BackgroundColor(), DrawMode.TilemapCache)
    DrawRect(248, 180, 3, 9, BackgroundColor(), DrawMode.TilemapCache)
    DrawRect(136, 220, 3, 9, BackgroundColor(), DrawMode.TilemapCache)



    pixelVisionOS:ChangeTitle(toolName, "toolbaricontool")

    pixelVisionOS:ShowMessageModal(toolName .. " Error", "The tool could not load without a reference to a file to edit.", 160, false,
      function()
        QuitCurrentTool()
      end
    )

  end



end

function OnConfig()

  local colorID = pixelVisionOS:CalculateRealColorIndex(systemColorPickerData) + systemColorPickerData.colorOffset

  -- TODO need to get the currently selected color
  editColorModal:SetColor(colorID)

  pixelVisionOS:OpenModal(editColorModal,
    function()

      if(editColorModal.selectionValue == true) then

        UpdateHexColor(editColorModal.colorHexInputData.text)
        -- Color(colorID, )

        -- Color(255, pixelVisionOS.maskColor)
        return
      end

    end
  )





end

function OnPalettePickerDrop(src, dest)
  -- print("Palette Picker On Drop", src.name, dest.name)

  -- Two modes, accept colors from the system color picker or swap colors in the palette

  if(src.name == systemColorPickerData.name) then

    -- Get the index and add 1 to offset it correctly
    local id = editorUI:CalculatePickerPosition(dest.picker).index + 1

    -- Get the correct hex value
    local srcHex = Color(pixelVisionOS:CalculateRealColorIndex(src, src.picker.selected) + src.colorOffset)

    if(usePalettes == false) then

      -- We want to manually toggle the palettes before hand so we can add the first color before calling the AddPalettePage()
      TogglePaletteMode(true, function() OnAddDroppedColor(id, dest, srcHex) end)

    else

      OnAddDroppedColor(id, dest, srcHex)
    end
  else
    -- print("Swap colors")

    OnSystemColorDropTarget(src, dest)

  end


end

function OnAddDroppedColor(id, dest, color)



  -- Make sure we are not adding a color outside of the size of the palette
  if(dest.name == paletteColorPickerData.name and id > paletteColorPickerData.visiblePerPage) then

    pixelVisionOS:DisplayMessage("Palette color was out of bounds.", 2)

    -- pixelVisionOS:ShowMessageModal(toolName .." Error", "You will need to increase the size of the palette in order to put a color there.", 160, false)

    return

  end

  local index = pixelVisionOS.colorOffset + 128 + (dest.pages.currentSelection - 1) * dest.totalPerPage + (id - 1)

  Color(index, color)

  pixelVisionOS:OnColorPageClick(dest, dest.pages.currentSelection)

  InvalidateData()

end

function OnSystemColorDropTarget(src, dest)

  -- If the src and the dest are the same, we want to swap colors
  if(src.name == dest.name) then

    -- Get the source color ID
    sourceColorID = src.currentSelection

    -- Exit this swap if there is no src selection
    if(sourceColorID == nil) then
      return
    end

    -- Get the destination color ID
    local destColorID = pixelVisionOS:CalculateColorPickerPosition(src).index

    -- Make sure the colors are not the same
    if(sourceColorID ~= destColorID) then

      -- Need to shift src and dest ids based onthe color offset
      local realSrcID = sourceColorID + src.colorOffset
      local realDestID = destColorID + dest.colorOffset

      -- Get the src and dest color hex value
      local srcColor = Color(realSrcID)
      local destColor = Color(realDestID)

      -- Make sure we are not moving a transparent color
      if(srcColor == pixelVisionOS.maskColor or destColor == pixelVisionOS.maskColor) then

        if(usePalettes == true and dest.name == systemColorPickerData.name) then

          pixelVisionOS:ShowMessageModal(toolName .." Error", "You can not replace the last color which is reserved for transparency.", 160, false)

          return

        end

      end

      -- Swap the colors in the tool's color memory
      Color(realSrcID, destColor)
      Color(realDestID, srcColor)

      -- Select the new color spot
      pixelVisionOS:SelectColorPickerColor(dest, destColorID)

      -- Redraw the color page
      pixelVisionOS:DrawColorPage(dest)

      pixelVisionOS:DisplayMessage("Color ID '"..srcColor.."' was swapped with Color ID '"..destColor .."'", 5)

      -- Invalidate the data so the tool can save
      InvalidateData()

    end

  end

end

function OnEditSprites()
  pixelVisionOS:ShowMessageModal("Edit Sprites", "Do you want to open the Sprite Editor? All unsaved changes will be lost.", 160, true,
    function()
      if(pixelVisionOS.messageModal.selectionValue == true) then

        -- Set up the meta data for the editor for the current directory
        local metaData = {
          directory = rootDirectory,
        }

        -- Load the tool
        LoadGame(spriteEditorPath, metaData)

      end

    end
  )
end

local lastMode = nil

-- Changes the focus of the currently selected color picker
function ForcePickerFocus(src)

  -- Only one picker can be selected at a time so remove the selection from the opposite one.
  if(src == nil) then

    -- Save the mode
    selectionMode = NoColorMode

    -- Disable input fields
    editorUI:Enable(colorIDInputData, false)
    ToggleHexInput(false)

    pixelVisionOS:ClearColorPickerSelection(systemColorPickerData)
    pixelVisionOS:ClearColorPickerSelection(paletteColorPickerData)



    -- Disable all option
    pixelVisionOS:EnableMenuItem(AddShortcut, false)
    pixelVisionOS:EnableMenuItem(ClearShortcut, false)
    pixelVisionOS:EnableMenuItem(EditShortcut, false)
    pixelVisionOS:EnableMenuItem(DeleteShortcut, false)
    pixelVisionOS:EnableMenuItem(BGShortcut, false)
    pixelVisionOS:EnableMenuItem(CopyShortcut, false)
    pixelVisionOS:EnableMenuItem(PasteShortcut, false)

  elseif(src.name == systemColorPickerData.name) then

    -- Change the color mode to system color mode
    selectionMode = SystemColorMode

    -- Clear the picker selection
    pixelVisionOS:ClearColorPickerSelection(paletteColorPickerData)

    -- Enable the hex input field
    ToggleHexInput(true)

  elseif(src.name == paletteColorPickerData.name) then

    -- Change the selection mode to palette mode
    selectionMode = PaletteMode

    -- Clear the system color picker selection
    pixelVisionOS:ClearColorPickerSelection(systemColorPickerData)

    -- Disable the hex input since you can't change palette colors directly
    ToggleHexInput(false)

  end

  -- Save the last mode
  lastMode = selectionMode

end

local copyValue = nil

function OnCopy()

  local src = lastMode == 1 and systemColorPickerData or paletteColorPickerData

  local colorID = pixelVisionOS:CalculateRealColorIndex(src) + src.colorOffset

  copyValue = Color(colorID)

  -- print("OnCopy", lastMode, src.name, colorID, copyValue)

  pixelVisionOS:EnableMenuItem(PasteShortcut, true)

  pixelVisionOS:DisplayMessage("Copied Color '"..copyValue .."'.")

end

function OnPaste()

  if(copyValue == nil) then
    return
  end

  local src = lastMode == 1 and systemColorPickerData or paletteColorPickerData

  local colorID = pixelVisionOS:CalculateRealColorIndex(systemColorPickerData)

  if(lastMode == 1) then
    -- print("Paste System Color", string.sub(copyValue, 2, 7))
    UpdateHexColor(string.sub(copyValue, 2, 7))
    -- AddSystemColor(colorID, copyValue)
  else
    Color(colorID, copyValue)
  end

  -- -- Find the currently selected picker
  -- local picker = selectionMode == SystemColorMode and systemColorPickerData or paletteColorPickerData
  --
  -- -- Redraw the pickers current page
  -- pixelVisionOS:DrawColorPage(picker)
  --
  -- InvalidateData()

  pixelVisionOS:EnableMenuItem(CopyShortcut, true)
  pixelVisionOS:EnableMenuItem(PasteShortcut, false)

end


function ToggleHexInput(value)
  editorUI:Enable(colorHexInputData, value)

  DrawText("#", 24, 26, DrawMode.Tile, "input", value and colorHexInputData.colorOffset or colorHexInputData.disabledColorOffset)

  if(value == false) then
    -- Clear values in fields
    -- Update the color id field
    editorUI:ChangeInputField(colorIDInputData, - 1, false)

    -- Update the color id field
    editorUI:ChangeInputField(colorHexInputData, string.sub(pixelVisionOS.maskColor, 2, 7), false)
  end
end

function TogglePaletteMode(value, callback)

  local data = paletteColorPickerData

  if(value == true) then

    -- If we are not using palettes, we need to warn the user before activating it

    pixelVisionOS:ShowMessageModal("Activate Palette Mode", "Do you want to activate palette mode? This will split color memory in half and allocate 128 colors to the system and 128 to palettes. The sprites will also be reindexed to the first palette. Saving will rewrite the 'sprite.png' file. This can not be undone.", 160, true,
      function()
        if(pixelVisionOS.messageModal.selectionValue == true) then

          -- Clear any colors in the clipboard
          copyValue = nil

          -- Set use palettes to true
          usePalettes = true

          -- Cop the colors to memory
          pixelVisionOS:CopyGameColorsToGameMemory()

          -- Update the palette mode in the meta data
          gameEditor:WriteMetaData("paletteMode", "true")

          -- Import the colors again
          pixelVisionOS:ImportColorsFromGame()

          -- Update the system color picker to match the new total colors
          systemColorPickerData.total = pixelVisionOS.totalSystemColors

          -- Reindex the sprites so they will work in palette mode
          gameEditor:ReindexSprites()

          spritesInvalid = true

          -- Redraw the sprite picker to they will display the correct colors
          pixelVisionOS:RedrawSpritePickerPage(spritePickerData)

          -- Clear focus
          ForcePickerFocus()

          -- Redraw the UI
          pixelVisionOS:RebuildPickerPages(systemColorPickerData)
          pixelVisionOS:SelectColorPage(systemColorPickerData, 1)

          -- Update the palette picker
          paletteColorPickerData.total = 128
          paletteColorPickerData.colorOffset = pixelVisionOS.colorOffset + 128

          -- Create the first palette from the first set of system colors
          for i = 1, paletteColorPickerData.total do
            local index = i - 1

            local color = i < gameEditor:ColorsPerSprite() and Color(index + pixelVisionOS.colorOffset) or pixelVisionOS.maskColor

            Color(index + pixelVisionOS.colorOffset + 129, color)

          end

          -- Force the palette picker to only display the total colors per sprite
          paletteColorPickerData.visiblePerPage = gameEditor:ColorsPerSprite()

          -- Redraw the palette UI
          RedrawPaletteUI()

          -- Select the first palette page
          pixelVisionOS:SelectColorPage(paletteColorPickerData, 1)

          -- Invalidate the data so the tool can save
          InvalidateData()

          -- Trigger any callback after this is done
          if(callback ~= nil) then
            callback()
          end

        end

      end
    )


  else

    pixelVisionOS:ShowMessageModal("Disable Palette Mode", "Disabeling the palette mode will return the game to 'Direct Color Mode'. Sprites will only display if they can match their colors to 'color.png' file. This process will also remove the palette colors and restore the system colors to support 256.", 160, true,
      function()
        if(pixelVisionOS.messageModal.selectionValue == true) then

          usePalettes = false

          pixelVisionOS.paletteMode = false

          -- Redraw the sprite picker
          spritePickerData.colorOffset = pixelVisionOS.colorOffset
          pixelVisionOS:RedrawSpritePickerPage(spritePickerData)

          -- Clear all palette colors
          for i = 128, 256 do
            Color(i + pixelVisionOS.colorOffset, pixelVisionOS.maskColor)
          end

          -- Update the system color picker to match the new total colors
          systemColorPickerData.total = 256

          pixelVisionOS:RebuildPickerPages(systemColorPickerData)
          pixelVisionOS:SelectColorPage(systemColorPickerData, 1)

          -- Clear focus
          ForcePickerFocus()


          -- Remove the palette page
          RedrawPaletteUI()

          InvalidateData()
          -- Update the game editor palette modes
          -- gameEditor:PaletteMode(usePalettes)

          -- TODO remove color pages

          if(callback ~= nil) then
            callback()
          end

        end

      end
    )

  end


end

function RedrawPaletteUI()

  if(usePalettes == true) then

    -- Draw edge
    DrawSprites(pickerbottompageedge.spriteIDs, 136 / 8, 216 / 8, pickerbottompageedge.width, false, false, DrawMode.Tile)

    local currentPage = paletteColorPickerData.pages.currentSelection

    -- Clear the current page
    paletteColorPickerData.pages.currentSelection = -1

    -- Rebuild the pages
    pixelVisionOS:RebuildPickerPages(paletteColorPickerData)

    -- Select the last page that was selected
    pixelVisionOS:SelectColorPage(paletteColorPickerData, currentPage)

  else

    -- Clear the background
    DrawSprites(palettepickerbackground.spriteIDs, 1, 184 / 8, palettepickerbackground.width, false, false, DrawMode.Tile)

    -- Redraw bottom border
    for i = 1, 9 do
      DrawSprites(palettepickerbottom.spriteIDs, 8 + i, 216 / 8, palettepickerbottom.width, false, false, DrawMode.Tile)
    end

    -- Draw edge
    DrawSprites(pickerbottompage.spriteIDs, 136 / 8, 216 / 8, pickerbottompage.width, false, false, DrawMode.Tile)

  end


end

function OnQuit()

  if(invalid == true) then

    pixelVisionOS:ShowMessageModal("Unsaved Changes", "You have unsaved changes. Do you want to save your work before you quit?", 160, true,
      function()
        if(pixelVisionOS.messageModal.selectionValue == true) then
          -- Save changes
          OnSave()

        end

        -- Quit the tool
        QuitCurrentTool()

      end
    )

  else
    -- Quit the tool
    QuitCurrentTool()
  end

end

function OnSave()

  -- Copy all of the colors over to the game
  pixelVisionOS:CopyGameColorsToGameMemory()

  -- These are the default flags we are going to save
  local flags = {SaveFlags.System, SaveFlags.Meta, SaveFlags.Colors, SaveFlags.ColorMap}

  -- TODO need to tell if we are not in palette mode any more and recolor sprites and delete color-map.png file?

  gameEditor:WriteMetaData("paletteMode", usePalettes and "true" or "false")

  -- If the sprites have been re-indexed and we are using palettes we need to save the changes
  if(spritesInvalid == true) then

    -- print("Save Sprites", usePalettes)
    if(usePalettes == true) then

      -- Add the color map flag
      table.insert(flags, SaveFlags.ColorMap)

    else
      -- TODO look for a color-map.png file in the current directory and delete it
    end

    -- Add the sprite flag
    table.insert(flags, SaveFlags.Sprites)

    spritesInvalid = false

  end

  -- This will save the system data, the colors and color-map
  gameEditor:Save(rootDirectory, flags)

  -- Display a message that everything was saved
  pixelVisionOS:DisplayMessage("Your changes have been saved.", 5)

  -- Clear the validation
  ResetDataValidation()

end

-- Adds a transparent color to the end of the system color or palette color picker. This only works if there is enough space and the system color picker doesn't already have a transparent color.
function OnAdd()

  -- TODO need to do a test to see what picker is selected and if in the system color picker, show the color editor before adding. If not do the below code


  -- Find the currently selected picker
  -- local picker = selectionMode == SystemColorMode and systemColorPickerData or paletteColorPickerData

  -- Test to see if we are in palette mode
  if(selectionMode == PaletteMode) then

    -- Make sure we are not at the end of the total per page value
    if(paletteColorPickerData.visiblePerPage < paletteColorPickerData.totalPerPage) then

      local colorID = pixelVisionOS:CalculateRealColorIndex(paletteColorPickerData)

      -- Increase the visible per page value by 1
      paletteColorPickerData.visiblePerPage = paletteColorPickerData.visiblePerPage + 1

      local currentPage = paletteColorPickerData.pages.currentSelection - 1

      local lastIndex = ((currentPage * 16) + paletteColorPickerData.visiblePerPage) - 1

      -- Redraw the pickers current page
      -- pixelVisionOS:DrawColorPage(paletteColorPickerData)

      RedrawPaletteUI()

      pixelVisionOS:SelectColorPickerColor(paletteColorPickerData, lastIndex)

      InvalidateData()

      -- Disable add option

      UpdateAddDeleteShortcuts()

      gameEditor:ColorsPerSprite(paletteColorPickerData.visiblePerPage)


    end

  end


  -- TODO Check to see what picker mode we are in
  -- TODO if system picker and palette mode, check to see if last color is transparent
  -- TODO only add system colors in palette mode if last color isn't transparent
  -- TODO in palette mode, add a new transparent color to the end

  -- TODO should this only be enabled when in palette mode on the palette picker?

  -- Invalidate the tool's data
  InvalidateData()

end

function UpdateAddDeleteShortcuts()

  -- Make sure add is active if there are extra color spaces in the palette
  pixelVisionOS:EnableMenuItem(AddShortcut, paletteColorPickerData.visiblePerPage < 16)

  -- Make sure delete is active if there are more than two colors
  pixelVisionOS:EnableMenuItem(DeleteShortcut, paletteColorPickerData.visiblePerPage > 2)

end

-- This method handles the logic for clearing a color based on the currently selected palette and the current color mode.
function OnClear()

  -- Find the currently selected picker
  local picker = selectionMode == SystemColorMode and systemColorPickerData or paletteColorPickerData

  -- Find the current color ID
  local colorID = pixelVisionOS:CalculateRealColorIndex(picker)

  -- Get the real color ID from the offset
  local realColorID = colorID + picker.colorOffset

  -- Set the color to the mask value
  Color(realColorID, pixelVisionOS.maskColor)

  -- Redraw the pickers current page
  pixelVisionOS:DrawColorPage(picker)

  -- Invalidate the tool's data
  InvalidateData()

end

function OnDelete()

  if(selectionMode == SystemColorMode) then
    OnDeleteSystemColor(pixelVisionOS:CalculateRealColorIndex(systemColorPickerData))
  elseif(selectionMode == PaletteMode) then
    OnDeletePaletteColor(pixelVisionOS:CalculateRealColorIndex(paletteColorPickerData))
  end
  --
  -- UpdateHexColor("ff00ff")
end

function UpdateHexColor(value)

  -- print("Update Hex Color", value)

  if(selectionMode == PaletteMode) then
    return
  end

  value = "#".. value

  local colorID = pixelVisionOS:CalculateRealColorIndex(systemColorPickerData)

  local realColorID = colorID + systemColorPickerData.colorOffset

  local currentColor = Color(realColorID)

  if(colorID == 255 and usePalettes == true) then

    pixelVisionOS:ShowMessageModal(toolName .." Error", "You can not replace the last color which is reserved for transparency.", 160, false,
      -- Make sure we restore the color value after the modal closes
      function()

        -- Change the color back to the original value in the input field
        editorUI:ChangeInputField(colorHexInputData, currentColor:sub(2, - 1), false)

      end
    )

    return

    -- Don't compare mask colors
  elseif(value == pixelVisionOS.maskColor) then

    if(usePalettes == false) then
      OnClear()
    else

      pixelVisionOS:ShowMessageModal(toolName .." Error", "You can not clear a color or set it to the mask value in Direct Color Mode.", 160, false)

    end

    return

  else

    -- Only block duplicated colors when palette mode is set to true
    if(usePalettes == true) then

      -- Make sure the color isn't duplicated when in palette mode
      for i = 1, 128 do

        -- Test the new color against all of the existing system colors
        if(value == Color(pixelVisionOS.colorOffset + (i - 1))) then

          pixelVisionOS:ShowMessageModal(toolName .." Error", "'".. value .."' the same as system color ".. (i - 1) ..", enter a new color.", 160, false,
            -- Make sure we restore the color value after the modal closes
            function()

              -- Change the color back to the original value in the input field
              editorUI:ChangeInputField(colorHexInputData, currentColor:sub(2, - 1), false)

            end
          )

          -- Exit out of the update function
          return

        end

      end

      -- Test if the color is at the end of the picker and the is room to add a new color
      if(colorID == systemColorPickerData.total - 1 and systemColorPickerData.total < 255) then

        -- TODO this should use the Add Color logic?
        pixelVisionOS:AddNewColorToPicker(systemColorPickerData)

        -- TODO need to rebuild the pages if we are in the system color picker

        -- Select the current color we are editing
        pixelVisionOS:SelectColorPickerColor(systemColorPickerData, realColorID)

      end

    end

    -- Update the editor's color
    local newColor = Color(realColorID, value)

    -- After updating the color, check to see if in palette mode and replace all matching colors in the palettes
    if(usePalettes == true) then

      -- Loop through the palette color memery to remove replace all matching colors
      for i = 127, pixelVisionOS.totalColors do

        local index = (i - 1) + pixelVisionOS.colorOffset

        -- Get the current color in the tool's memory
        local tmpColor = Color(index)

        -- See if that color matches the old color
        if(tmpColor == currentColor and tmpColor ~= pixelVisionOS.maskColor) then

          -- Set the color to equal the new color
          Color(index, value)

        end

      end

    end

    -- Redraw the pickers current page
    pixelVisionOS:DrawColorPage(systemColorPickerData)

    InvalidateData()

  end

end

function OnDeleteSystemColor(value)

  if(usePalettes == false) then

    pixelVisionOS:ShowMessageModal("Delete Color", "Are you sure you want to delete this color? Since you are in Direct Color Mode, the selected color will be set to the mask color.", 160, true,
      function()
        if(pixelVisionOS.messageModal.selectionValue == true) then
          DeleteSystemColor(value)
        end

      end
    )


  else

    -- Calculate the total system colors from the picker
    local totalColors = systemColorPickerData.total - 1

    -- Test to see if we are on the last color
    if(value == totalColors) then

      -- Display a message to keep the user from deleting the mask color
      pixelVisionOS:ShowMessageModal(toolName .. " Error", "You can't delete the transparent color.", 160, false)

      -- Test to see if we only have one color left
    elseif(totalColors == 1) then

      -- Display a message to keep the user from deleting all of the system colors
      pixelVisionOS:ShowMessageModal(toolName .. " Error", "You must have at least 1 color.", 160, false)

    else

      pixelVisionOS:ShowMessageModal("Delete Color", "Are you sure you want to delete this system color? Doing so will shift all the colors over and may change the colors in your sprites." .. (usePalettes and " This color will also be removed from any palettes that are referencing it." or ""), 160, true,
        function()
          if(pixelVisionOS.messageModal.selectionValue == true) then
            -- If the selection if valid, remove the system color
            DeleteSystemColor(value)
          end

        end
      )
    end
  end

end

function DeleteSystemColor(value)

  -- Calculate the real color ID in the tool's memory
  local realColorID = value + systemColorPickerData.colorOffset

  -- Set the current tool's color to the mask value
  Color(realColorID, pixelVisionOS.maskColor)

  -- Loop through all the palette colors and remove it as well
  if(usePalettes) then

  end

  -- Copy all the colors to the game
  pixelVisionOS:CopyGameColorsToGameMemory()

  -- Reimport the game colors to rebuild the unique system color list
  pixelVisionOS:ImportColorsFromGame()

  -- Update the system picker with the new page total
  pixelVisionOS:ChangeColorPickerTotal(systemColorPickerData, pixelVisionOS.totalSystemColors)

  -- Deselect the system picker
  ForcePickerFocus()

  RedrawPaletteUI()

  -- Invalidate the tool's data
  InvalidateData()

end
function OnDeletePaletteColor(value)

  local totalColors = paletteColorPickerData.visiblePerPage

  if(totalColors == 2) then

    -- Display a message to keep the user from deleting all of the system colors
    pixelVisionOS:ShowMessageModal(toolName .. " Error", "You must have at least 2 colors in a palette.", 160, false)

    return

  else

    pixelVisionOS:ShowMessageModal("Delete Palette Color", "Are you sure you want to delete this palette color position? This will remove palette index '".. value .."' from all of the palettes and reduce the colors per sprite value by 1. This may change the way your sprites look and can not be undone once the changes have been saved.", 160, true,
      function()
        if(pixelVisionOS.messageModal.selectionValue == true) then




          local colorID = pixelVisionOS:CalculateRealColorIndex(paletteColorPickerData)

          local lastIndex = 0
          local remainingColors = totalColors - colorID

          -- Loop through all the colors at the current palette position and clear them in each palette
          for i = 8, 1, - 1 do
            -- Clear color

            -- local colorIndex = paletteColorPickerData.visiblePerPage

            -- print("Modify palette", i, colorID, remainingColors)
            for j = colorID, remainingColors do


              local nextColorID = (((i - 1) * 16)) + j + 1 + paletteColorPickerData.colorOffset
              -- local nextColor =
              -- lastIndex = (((i - 1) * 16) + colorID)

              local nextColor = j >= 15 and pixelVisionOS.maskColor or Color(nextColorID)
              -- print("Color Shift", nextColorID, Color(nextColorID))
              Color(nextColorID - 1, nextColor)

            end


          end

          -- Increase the visible per page value by 1
          paletteColorPickerData.visiblePerPage = totalColors - 1

          -- Calculate the current page
          local currentPage = paletteColorPickerData.pages.currentSelection - 1

          -- Find the last position
          local lastIndex = ((currentPage * 16) + paletteColorPickerData.visiblePerPage)

          RedrawPaletteUI()

          pixelVisionOS:SelectColorPickerColor(paletteColorPickerData, lastIndex - 1)

          InvalidateData()

          -- Disable add option

          UpdateAddDeleteShortcuts()

          gameEditor:ColorsPerSprite(paletteColorPickerData.visiblePerPage)

        end

      end
    )
  end

end

function DeletePaletteColor(value)

  -- Calculate the real color ID in the tool's memory
  local realColorID = value + systemColorPickerData.colorOffset

  -- Set the current tool's color to the mask value
  Color(realColorID, pixelVisionOS.maskColor)

  -- Loop through all the palette colors and remove it as well
  if(usePalettes) then

  end

  -- Copy all the colors to the game
  pixelVisionOS:CopyGameColorsToGameMemory()

  -- Reimport the game colors to rebuild the unique system color list
  pixelVisionOS:ImportColorsFromGame()

  -- Update the system picker with the new page total
  pixelVisionOS:ChangeColorPickerTotal(systemColorPickerData, pixelVisionOS.totalSystemColors)

  -- Deselect the system picker
  ForcePickerFocus()

  RedrawPaletteUI()

  -- Invalidate the tool's data
  InvalidateData()

end

-- Manages selecting the correct color from a picker based on a change to the color id field
function ChangeColorID(value)

  -- print("Change Color ID", value)
  -- Check to see what mode we are in
  if(selectionMode == SystemColorMode) then

    -- Select the new color id in the system color picker
    pixelVisionOS:SelectColorPickerColor(systemColorPickerData, value)

  elseif(selectionMode == PaletteMode) then

    -- Select the new color id in the palette color picker
    pixelVisionOS:SelectColorPickerColor(paletteColorPickerData, value)

  end

end

local lastSelection = nil
local lastColor = nil

-- This is called when the picker makes a selection
function OnSelectSystemColor(value)

  -- Calculate the color ID from the picker
  local colorID = pixelVisionOS:CalculateRealColorIndex(systemColorPickerData, value)

  -- Update the ID input field's max value from the OS's system color total
  colorIDInputData.max = pixelVisionOS.totalSystemColors - 1

  -- Enable the color id input field
  editorUI:Enable(colorIDInputData, true)

  -- Update the color id field
  editorUI:ChangeInputField(colorIDInputData, tostring(colorID), false)

  -- Enable the hex input field
  ToggleHexInput(true)

  -- Get the current hex value of the selected color
  local colorHex = Color(colorID + systemColorPickerData.colorOffset):sub(2, - 1)

  if(lastSelection ~= value) then

    lastSelection = value
    lastColor = colorHex

  end

  -- Update the selected color hex value
  editorUI:ChangeInputField(colorHexInputData, colorHex, false)

  -- Update menu menu items

  -- TODO need to enable this when the color editor pop-up is working
  pixelVisionOS:EnableMenuItem(EditShortcut, true)

  -- These are only available based on the palette mode
  pixelVisionOS:EnableMenuItem(AddShortcut, false)
  pixelVisionOS:EnableMenuItem(DeleteShortcut, usePalettes)
  pixelVisionOS:EnableMenuItem(BGShortcut, ("#"..colorHex) ~= pixelVisionOS.maskColor)

  -- You can only copy a color when in direct color mode
  pixelVisionOS:EnableMenuItem(ClearShortcut, not usePalettes)
  pixelVisionOS:EnableMenuItem(CopyShortcut, true)

  -- Only enable the paste button if there is a copyValue and we are not in palette mode
  pixelVisionOS:EnableMenuItem(PasteShortcut, copyValue ~= nil and usePalettes == false)

end

function OnSelectPaletteColor(value)

  local colorID = pixelVisionOS:CalculateRealColorIndex(paletteColorPickerData, value)

  colorIDInputData.max = 256

  -- Disable the hex input field
  ToggleHexInput(false)
  editorUI:Enable(colorIDInputData, false)

  editorUI:ChangeInputField(colorIDInputData, tostring(colorID + 128), false)

  local colorHex = Color(colorID + paletteColorPickerData.colorOffset):sub(2, - 1)

  -- Update the selected color hex value
  editorUI:ChangeInputField(colorHexInputData, colorHex, false)

  -- Update menu menu items
  pixelVisionOS:EnableMenuItem(EditShortcut, false)
  pixelVisionOS:EnableMenuItem(ClearShortcut, true)
  UpdateAddDeleteShortcuts()
  pixelVisionOS:EnableMenuItem(CopyShortcut, true)

  -- Only enable the paste button if there is a copyValue and we are not in palette mode
  pixelVisionOS:EnableMenuItem(PasteShortcut, copyValue ~= nil and usePalettes == true)

end

function Update(timeDelta)

  -- This needs to be the first call to make sure all of the editor UI is updated first
  pixelVisionOS:Update(timeDelta)

  -- Only update the tool's UI when the modal isn't active
  if(pixelVisionOS:IsModalActive() == false) then

    if(success == true) then

      pixelVisionOS:UpdateSpritePicker(spritePickerData)

      editorUI:UpdateInputField(colorIDInputData)
      editorUI:UpdateInputField(colorHexInputData)

      -- System picker
      pixelVisionOS:UpdateColorPicker(systemColorPickerData)

      -- Only update the palette color picker when we are in palette mode
      if(usePalettes == true) then
        pixelVisionOS:UpdateColorPicker(paletteColorPickerData)
      end

      if(IsExporting()) then
        pixelVisionOS:DisplayMessage("Saving " .. tostring(ReadExportPercent()).. "% complete.", 2)
      end

    end

  end

end

function Draw()

  RedrawDisplay()

  -- The ui should be the last thing to update after your own custom draw calls
  pixelVisionOS:Draw()

  if(showBGIcon == true and pixelVisionOS:IsModalActive() == false) then

    DrawSprites(bgflagicon.spriteIDs, systemColorPickerData.rect.x + BGIconX, systemColorPickerData.rect.y + BGIconY, bgflagicon.width)

  end

  if(debugMode) then
    colorMemoryCanvas:DrawPixels(256 - (8 * 3) - 2, 12, DrawMode.UI, 3)
  end

end

function Shutdown()

  -- WriteSaveData("editing", gameEditor:Name())
  -- WriteSaveData("tab", tostring(colorTabBtnData.currentSelection))
  -- WriteSaveData("selected", CalculateRealIndex(systemColorPickerData.picker.selected))

  -- Save the current session ID
  WriteSaveData("sessionID", SessionID())

  WriteSaveData("rootDirectory", rootDirectory)

  -- TODO need to save the last set of selections
  WriteSaveData("selectedColor", systemColorPickerData.currentSelection)
  WriteSaveData("selectedPalette", paletteColorPickerData.currentSelection)
  WriteSaveData("selectedSprite", spritePickerData.currentSelection)



end

function OnSetBGColor()

  local oldBGColor = gameEditor:BackgroundColor()

  local colorID = pixelVisionOS:CalculateRealColorIndex(systemColorPickerData)

  pixelVisionOS:ShowMessageModal("Set Background Color", "Do you want to change the current background color ID from " .. oldBGColor .. " to " .. colorID .. "?", 160, true,
    function()
      if(pixelVisionOS.messageModal.selectionValue == true) then

        gameEditor:BackgroundColor(colorID)

        showBGIcon = true

        UpdateBGIconPosition(colorID)

        InvalidateData()
      end
    end
  )

end

function UpdateBGIconPosition(id)

  local pos = CalculatePosition(id % 64, 8)

  BGIconX = pos.x * 16
  BGIconY = pos.y * 16

end
