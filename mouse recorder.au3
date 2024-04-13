#include <GuiConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#Include <Misc.au3>
#include <Date.au3>
#include <Timers.au3>
#include <Array.au3>
; #NoTrayIcon 
AutoItSetOption("MustDeclareVars", 1)
; --------------------- setting up GUI ---------------------
Local $myGUI = GuiCreate("MooV", 200, 180, -1, -1, $GUI_SS_DEFAULT_GUI, $WS_EX_TOPMOST) 
; BitOR($WS_EX_WINDOWEDGE, $WS_EX_TOPMOST)
Opt("GUIOnEventMode", 1)
; Opt("GUICloseOnESC", 1) 
GUISetBkColor (0x529CFE)
Local $buttonStart = GuiCtrlCreateButton("Record [hotkey=PGDN]", 10, 10, 180, 25)
GUICtrlSetOnEvent(-1, "buttonStart_onClick")
Local $buttonStop = GuiCtrlCreateButton("Stop [hotkey=PGDN]", 10, 45, 180, 25)
GUICtrlSetOnEvent(-1, "buttonStop_onClick")
GuiCtrlSetState($buttonStop, $GUI_DISABLE)
Local $labelInfo = GuiCtrlCreateLabel("no recording loaded", 10, 80, 180, 30)
Local $buttonLoad = GuiCtrlCreateButton("Load a record file", 10, 115, 180, 25)
GUICtrlSetOnEvent(-1, "buttonLoad_onClick")
Local $buttonReplay = GuiCtrlCreateButton("Replay [hotkey=PAUSE]", 10, 145, 180, 25)
GUICtrlSetOnEvent(-1, "buttonReplay_onClick")
GUISetOnEvent($GUI_EVENT_CLOSE, "buttonExit_onClick", $myGUI)
GuiSetState(@SW_SHOW) ; show gui
; --------------------- Global state ---------------------
Global $isRecordingMode = 0
Global $isPlaybackMode = 0
Global $loadedRecording[0]
; --------------------- hot keys ---------------------
HotKeySet("{PAUSE}", "hotkeyToggleReplay")
HotKeySet("{PGDN}", "hotkeyToggleRecord")
Func hotkeyToggleReplay()
	If $isRecordingMode Then Return 0
	$isPlaybackMode = Not $isPlaybackMode	
EndFunc
Func hotkeyToggleRecord()
	If $isPlaybackMode Then Return 0
	$isRecordingMode = Not $isRecordingMode	
EndFunc
; --------------------- GUI handlers ---------------------
Func buttonStart_onClick ()
	; MsgBox($MB_SYSTEMMODAL, "", "start pressed")
	$isRecordingMode = 1
EndFunc
Func buttonStop_onClick()
	; MsgBox($MB_SYSTEMMODAL, "", "stop pressed")
	$isRecordingMode = 0	
EndFunc
Func buttonExit_onClick()
	; MsgBox($MB_SYSTEMMODAL, "", "exit pressed")
	Exit
EndFunc
Func buttonReplay_onClick()
	; MsgBox($MB_SYSTEMMODAL, "", "replay pressed")
	$isPlaybackMode = 1
EndFunc
Func buttonLoad_onClick()
	; MsgBox($MB_SYSTEMMODAL, "", "load pressed")
	; use IniRead ( "filename", "section", "key", "default" )
	Local $file = FileOpenDialog("Choose a .ini file that contains the recording", Default, "(*.ini)", BitOR($FD_FILEMUSTEXIST , $FD_PATHMUSTEXIST))
	
	If Not @ERROR Then		
		Local $fileData = IniReadSection($file, "Record")
		; _ArrayDisplay($fileData)
		Local $stepCount = UBound($fileData) - 1  ; $fileData[0][0] is # of records
		Local $tempSteps[0]
		For $i = 1 To $stepCount
			_ArrayAdd($tempSteps, $fileData[$i][1])
		Next
		$loadedRecording = $tempSteps
		GUICtrlSetData($labelInfo, "Record of " & $stepCount & " steps loaded")
	EndIf
	
EndFunc
; --------------------- helpers ---------------------
Func getTS()
	Return _Timer_Init( )
EndFunc
Func msSinceTS($timestamp)
	Return Floor(_Timer_Diff($timestamp))
EndFunc
;----------------------------------------------------------------
;  Keep process alive, handle modes based on global state
; (loops in Func's block gui events)
;----------------------------------------------------------------
While 1
	Local $isIdle = (Not $isRecordingMode) And (Not $isPlaybackMode)
	
	; --------------------- record ---------------------
	If $isRecordingMode Then		
		GuiCtrlSetState($buttonStart, $GUI_DISABLE)		
		GuiCtrlSetState($buttonStop, $GUI_ENABLE)
		GuiCtrlSetState($buttonLoad, $GUI_DISABLE)
		GuiCtrlSetState($buttonReplay, $GUI_DISABLE)
		ToolTip("recording (PGDN to turn off)", 0, 0)
		
		Local $recordingTitle = @YEAR & "_" & @MON & "_" & @MDAY & "_" & @HOUR & "_" & @MIN & "_" & @SEC
		
		; sensitivity settings, record on button change, max delay between steps reached, or distance traveled
		Local $recordingMaxDelay = 250 ; ms between recorded steps max
		Local $recordingMaxDistance = 12 ; px travel per axis
		
		; initialize reused vars
		Local $recordingArray[0]		
		Local $startedTime = getTS()
		Local $lastStepElapsedTime = -$recordingMaxDelay
		Local $elapsedTime = 0
		
		; predeclare temp vars
		Local $pos = MouseGetPos()	
		Local $lastLMB = 0
		Local $lastX = $pos[0] 
		Local $lastY = $pos[1]
		Local $posX = $pos[0] 
		Local $posY = $pos[1]
		Local $nowLMB,	$encodedRecord, $maxDelayReached, $changedLMB, $addNewStep, $maxDistancedReached
		
		While $isRecordingMode
			$elapsedTime = msSinceTS($startedTime)
			
			$maxDelayReached = $elapsedTime - $lastStepElapsedTime > $recordingMaxDelay
			
			$nowLMB = _IsPressed('01') ? 1 : 0
			$changedLMB = $nowLMB <> $lastLMB
			$lastLMB = $nowLMB
			
			$pos = MouseGetPos()
			$posX = $pos[0] 
			$posY = $pos[1]
			$maxDistancedReached = Abs($posX - $lastX) > $recordingMaxDistance Or Abs($posY - $lastY) > $recordingMaxDistance
			
			; add new step if max time reached OR lmb pressed status changed OR max distance traveled reached
			$addNewStep = $maxDelayReached Or $changedLMB Or $maxDistancedReached
			If $addNewStep Then
				$lastStepElapsedTime = $elapsedTime					               
				$encodedRecord = $elapsedTime & "," & $posX & "," & $posY & "," & $nowLMB						
				_ArrayAdd($recordingArray, $encodedRecord)				
				$lastX = $posX 
				$lastY = $posY
			EndIf			
			
			Sleep(10) ; has to be small for _IsPressed to notice most mouse presses
		WEnd
		
		Local $stepCount = Ubound($recordingArray)
		; _ArrayDisplay($recordingArray)
		
		; treat this recording as loaded recording
		$loadedRecording = $recordingArray
		GUICtrlSetData($labelInfo, "Record of " & $stepCount & " steps loaded")
		
		; record each step into a file			
		Local $filepath = @ScriptDir & "\Recording " & $recordingTitle &  ".ini"
		For $i = 0 To $stepCount - 1			
			IniWrite($filepath, "record", $i, $recordingArray[$i]) ; @DeskTopCommonDir
		Next
		
		ToolTip("")
		GuiCtrlSetState($buttonStart, $GUI_ENABLE)		
		GuiCtrlSetState($buttonStop, $GUI_DISABLE)
		GuiCtrlSetState($buttonLoad, $GUI_ENABLE)
		GuiCtrlSetState($buttonReplay, $GUI_ENABLE)	
	EndIf	
	
	; --------------------- playback ---------------------
	If $isPlaybackMode Then
		GuiCtrlSetState($buttonStart, $GUI_DISABLE)		
		GuiCtrlSetState($buttonStop, $GUI_DISABLE)
		GuiCtrlSetState($buttonLoad, $GUI_DISABLE)
		GuiCtrlSetState($buttonReplay, $GUI_DISABLE)		
		ToolTip("replaying (PAUSE to turn off)", 0, 0)
		
		Local $stepCount = Ubound($loadedRecording)		
		
		; load steps
		Local $stepData[0]
		For $i = 0 To $stepCount - 1			
			_ArrayAdd($stepData, _ArrayFromString($loadedRecording[$i], ","), Default, Default, Default, $ARRAYFILL_FORCE_SINGLEITEM)
		Next
		
		While ($isPlaybackMode)			
			Local $startedTime = getTS()
			Local $elapsedTime = 0
			Local $nextTime, $nextX, $nextY, $nextLMB
			Local $lastTime, $lastX, $lastY
			Local $progress, $tempX, $tempY
		
			For $step = 1 To $stepCount - 1
				
				$nextTime = ($stepData[$step])[0]			
				$nextX = ($stepData[$step])[1]
				$nextY = ($stepData[$step])[2]
				$nextLMB = ($stepData[$step])[3]
				
				$lastTime = ($stepData[$step - 1])[0]	
				$lastX = ($stepData[$step])[1]
				$lastY = ($stepData[$step])[2]
				
				; use time to place mouse at interpolated coods between 2 points
				$elapsedTime = msSinceTS($startedTime)			
				While ($elapsedTime < $nextTime)
					
					Local $progress = ($elapsedTime - $lastTime) / ($nextTime - $lastTime)
					$tempX = Floor(($nextX - $lastX) * $progress + $lastX)
					$tempY = Floor(($nextY - $lastY) * $progress + $lastY)
					MouseMove($tempX, $tempY, 1)
					
					$elapsedTime = msSinceTS($startedTime)
				WEnd
				
				If ($nextLMB = 1) Then MouseDown($MOUSE_CLICK_LEFT)
				If ($nextLMB = 0) Then MouseUp($MOUSE_CLICK_LEFT)
				
				If ($isPlaybackMode = 0) Then ExitLoop
			Next
		WEnd			
		
		GuiCtrlSetState($buttonStart, $GUI_ENABLE)		
		GuiCtrlSetState($buttonStop, $GUI_DISABLE)
		GuiCtrlSetState($buttonLoad, $GUI_ENABLE)
		GuiCtrlSetState($buttonReplay, $GUI_ENABLE)		
		ToolTip("")	
		$isPlaybackMode = 0
	EndIf
		
	If ($isIdle) Then	Sleep(100) ; Sleep to reduce CPU usage
WEnd
