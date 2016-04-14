
-- Abstract: MediaBrix
-- Version: 1.0
-- Sample code is MIT licensed; see https://www.coronalabs.com/links/code/license
---------------------------------------------------------------------------------------

display.setStatusBar( display.HiddenStatusBar )

------------------------------
-- RENDER THE SAMPLE CODE UI
------------------------------
local sampleUI = require( "sampleUI.sampleUI" )
sampleUI:newUI( { theme="darkgrey", title="MediaBrix", showBuildNum=true } )

------------------------------
-- CONFIGURE STAGE
------------------------------
display.getCurrentStage():insert( sampleUI.backGroup )
local mainGroup = display.newGroup()
local placementGroup = display.newGroup() ; mainGroup:insert( placementGroup )
display.getCurrentStage():insert( sampleUI.frontGroup )

----------------------
-- BEGIN SAMPLE CODE
----------------------

-- Require libraries/plugins
local mediaBrix = require( "plugin.mediaBrix" )
local widget = require( "widget" )

-- Set app font
local appFont = sampleUI.appFont

-- Preset the MediaBrix app ID (replace this with your own for testing/release)
-- This will be sent to you following completion of the MediaBrix registration process: https://platform.mediabrix.com/signup
local appID = "[YOUR-APP-ID]"

-- Preset the MediaBrix placement IDs (replace these with your own for testing/release)
local testPlacementTable = {
	iOS = { "IOS_Rally", "IOS_Rescue", "IOS_Rewards" },
	android = { "Android_Rally", "Android_Rescue", "Android_Rewards" }
}
local testPlacements
if ( system.getInfo("platformName") == "Android" ) then
	testPlacements = testPlacementTable["android"]
elseif ( system.getInfo("platformName") == "iPhone OS" ) then
	testPlacements = testPlacementTable["iOS"]
end

-- Set local variables
local setupComplete = false
local currentPlacement = 1
local loadButton
local showButton

-- Create asset image sheet
local assets = graphics.newImageSheet( "assets.png",
	{
		frames = {
			{ x=0, y=0, width=35, height=35 },
			{ x=0, y=35, width=35, height=35 },
		},
		sheetContentWidth=35, sheetContentHeight=70
	}
)

-- Create object to visually prompt action
local prompt = display.newPolygon( mainGroup, 62, 285, { 0,-12, 12,0, 0,12 } )
prompt:setFillColor( 0.8 )
prompt.alpha = 0

-- Create spinner widget for indicating ad status
if ( system.getInfo( "platformName" ) ~= "tvOS" ) then widget.setTheme( "widget_theme_android_holo_light" ) end
local spinner = widget.newSpinner( { x=display.contentCenterX, y=410, deltaAngle=10, incrementEvery=10 } )
mainGroup:insert( spinner )
spinner.alpha = 0


-- Function to manage spinner appearance/animation
local function manageSpinner( action )
	if ( action == "show" ) then
		spinner:start()
		transition.cancel( "spinner" )
		transition.to( spinner, { alpha=1, tag="spinner", time=((1-spinner.alpha)*320), transition=easing.outQuad } )
	elseif ( action == "hide" ) then
		transition.cancel( "spinner" )
		transition.to( spinner, { alpha=0, tag="spinner", time=((1-(1-spinner.alpha))*320), transition=easing.outQuad,
			onComplete=function() spinner:stop(); end } )
	end
end


-- Function to prompt/alert user for setup
local function checkSetup()

	if ( system.getInfo( "environment" ) ~= "device" ) then return end

	if ( tostring(appID) == "[YOUR-APP-ID]" ) then
		local alert = native.showAlert( "Important", 'Confirm that you have specified your unique MediaBrix app ID within "main.lua" on line 36. This will be sent to you following completion of the MediaBrix registration process.', { "OK", "mediabrix.com" },
			function( event )
				if ( event.action == "clicked" and event.index == 2 ) then
					system.openURL( "http://platform.mediabrix.com/" )
				end
			end )
	else
		setupComplete = true
	end
end


-- Function to update button visibility/state
local function updateUI( params )

	-- Disable inactive buttons
	if ( params["disable"] ) then
		for i = 1,#params["disable"] do
			params["disable"][i]:setEnabled( false )
			params["disable"][i].alpha = 0.3
		end
	end

	-- Move/transition prompt
	if ( params["promptTo"] ) then
		transition.to( prompt, { y=params["promptTo"].y, alpha=1, tag="prompt", time=400, transition=easing.outQuad } )
		prompt.isOn = params["promptTo"]
	end

	-- Enable new active buttons
	if ( params["enable"] ) then
		timer.performWithDelay( 400,
			function()
				for i = 1,#params["enable"] do
					params["enable"][i]:setEnabled( true )
					params["enable"][i].alpha = 1
				end
			end
		)
	end
end


-- MediaBrix event listener
local function adListener( event )

	-- Exit function if user hasn't set up testing parameters
	if ( setupComplete == false ) then return end

	-- Successful initialization of the MediaBrix plugin
	if ( event.phase == "init" ) then
		print( "MediaBrix event: initialization successful" )
		updateUI( { enable={ loadButton }, disable={ showButton }, promptTo=loadButton } )

	-- An ad loaded successfully
	elseif ( event.phase == "loaded" ) then
		print( "MediaBrix event: " .. tostring(event.type) .. " ad loaded successfully" )
		updateUI( { enable={ showButton }, disable={ loadButton }, promptTo=showButton } )
		manageSpinner( "hide" )

	-- The ad was displayed
	elseif ( event.phase == "displayed" ) then
		print( "MediaBrix event: " .. tostring(event.type) .. " ad displayed" )
		updateUI( { disable={ showButton } } )

	-- The ad was closed
	elseif ( event.phase == "closed" ) then
		print( "MediaBrix event: " .. tostring(event.type) .. " ad closed" )
		updateUI( { enable={ loadButton }, disable={ showButton }, promptTo=loadButton } )

	-- The ad failed to load
	elseif ( event.phase == "failed" ) then
		print( "MediaBrix event: " .. tostring(event.type) .. " ad failed to load" )
		manageSpinner( "hide" )

	-- The user viewed a rewarded/incentivized ad
	elseif ( event.phase == "reward" ) then
		print( "MediaBrix event: " .. tostring(event.type) .. " ad viewed and reward accepted" )
		updateUI( { disable={ showButton } } )
	end
end


-- Button handler function
local function uiEvent( event )

	if ( event.target.id == "load" ) then
		mediaBrix.load( testPlacements[currentPlacement] )
		manageSpinner( "show" )
	elseif ( event.target.id == "show" ) then
		mediaBrix.show( testPlacements[currentPlacement] )
	end
	return true
end

-- Create placement ID switches/labels
if ( testPlacements ~= nil ) then

	local placementLabel = display.newText( placementGroup, "Select Placement ID", display.contentCenterX, 104, appFont, 20 )

	for i = 1,#testPlacements do
		local isOn = false ; if ( i == 1 ) then isOn = true; currentPlacement = 1 end
		local radioButton = widget.newSwitch(
			{
				sheet = assets,
				width = 35,
				height = 35,
				frameOn = 1,
				frameOff = 2,
				x = display.contentCenterX - 70,
				y = (placementLabel.contentBounds.yMax-10)+(i*36),
				style = "radio",
				id = i,
				initialSwitchState = isOn,
				onPress = function( event ) currentPlacement = i; end
			})
		placementGroup:insert( radioButton )
		local label = display.newText( placementGroup, testPlacements[i], radioButton.contentBounds.xMax+4, radioButton.y, appFont, 16 )
		label.anchorX = 0
	end
end

-- Create buttons
loadButton = widget.newButton(
	{
		label = "Load MediaBrix Ad",
		id = "load",
		shape = "rectangle",
		x = display.contentCenterX + 10,
		y = 285,
		width = 188,
		height = 32,
		font = appFont,
		fontSize = 16,
		fillColor = { default={ 0.16,0.36,0.56,1 }, over={ 0.16,0.36,0.56,1 } },
		labelColor = { default={ 1,1,1,1 }, over={ 1,1,1,0.8 } },
		onRelease = uiEvent
	})
loadButton:setEnabled( false )
loadButton.alpha = 0.3
mainGroup:insert( loadButton )
prompt.isOn = loadButton

showButton = widget.newButton(
	{
		label = "Show MediaBrix Ad",
		id = "show",
		shape = "rectangle",
		x = display.contentCenterX + 10,
		y = 335,
		width = 188,
		height = 32,
		font = appFont,
		fontSize = 16,
		fillColor = { default={ 0.16,0.36,0.56,1 }, over={ 0.16,0.36,0.56,1 } },
		labelColor = { default={ 1,1,1,1 }, over={ 1,1,1,0.8 } },
		onRelease = uiEvent
	})
showButton:setEnabled( false )
showButton.alpha = 0.3
mainGroup:insert( showButton )

-- Update the app layout on resize event
local function onResize( event )

	loadButton.x = display.contentCenterX + 10
	showButton.x = display.contentCenterX + 10
	transition.cancel( "prompt" )

	if ( system.orientation == "landscapeLeft" or system.orientation == "landscapeRight" ) then
		loadButton.y, showButton.y = 225, 275
		placementGroup.x, placementGroup.y = 80, -40
		prompt.x, prompt.y = 142, prompt.isOn.y
		spinner.x, spinner.y = 400, 250
	elseif ( system.orientation == "portrait" or system.orientation == "portraitUpsideDown" ) then
		loadButton.y, showButton.y = 285, 335
		placementGroup.x, placementGroup.y = 0, 0
		prompt.x, prompt.y = 62, prompt.isOn.y
		spinner.x, spinner.y = display.contentCenterX, 410
	end
end
Runtime:addEventListener( "resize", onResize )

-- Initially alert user to set up device for testing
checkSetup()

-- Initialize MediaBrix
mediaBrix.init( adListener, { appId=appID } )
