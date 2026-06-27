--[[
	Room3_CodeBlue.luau
	Module: ReplicatedStorage/NurseWorld/Room3_CodeBlue
	
	ROOM 3 — Ms. Chen — Code Blue Emergency
	Mechanic: Multi-phase interactive emergency response
	
	FLOW:
	======
	Phase 0 — CALM (4 seconds)
		Player enters. Heart monitor beeps steadily at 78 bpm.
		A prompt says "Monitor the patient's vitals..."
		Everything looks normal. Calm ambient sounds.
	
	Phase 1 — DETERIORATION (3 seconds, automatic)
		Heart rate starts dropping: 72 → 65 → 58 → 40 → FLATLINE
		Monitor beeping slows, then flatlines. Alarm sounds.
		Room lighting shifts to red/emergency.
		Screen flashes warning.
	
	Phase 2 — CALL THE CODE (5 second window)
		Prompt: "EMERGENCY — Hit the Code Blue button!"
		A large button appears on screen (or player clicks emergency
		call button on the wall). Must click within 5 seconds.
		If too slow: lose points, but continue anyway.
	
	Phase 3 — CPR COMPRESSIONS (rhythm-based)
		A rhythm guide appears on screen:
		- A pulsing circle that expands and contracts at 110 bpm
		  (middle of the 100-120 target range)
		- Player must CLICK when the circle hits the target zone
		- Need 15 successful compressions to fill the progress bar
		- "Good" / "Perfect" / "Miss" feedback per click
		- Too early or too late = Miss
		- Timer: 20 seconds to complete 15 compressions
	
	Phase 4 — DEFIBRILLATOR (quick-time event)
		AED prompt appears:
		- Step 1: "CLEAR THE PATIENT" — click Clear button (3 sec window)
		- Step 2: "SHOCK" — click Shock when the indicator is in the green zone
		  (timing-based, like stopping a moving bar)
	
	Phase 5 — OUTCOME
		SUCCESS (score >= passing threshold):
			- Heartbeat returns (beep... beep... beep)
			- Monitor shows normal sinus rhythm
			- Room lights return to normal
			- "Patient stabilized. Your quick response saved a life."
		
		FAILURE (score < passing threshold):
			- Flatline continues
			- Screen slowly fades darker
			- Patient spirit/ghost rises slowly from the bed
			  (transparent humanoid floats upward)
			- "Patient lost. Every second matters in a Code Blue."
			- Somber music plays
	
	SCORING:
	========
	- Call the Code: 15 points (0 if missed within window)
	- CPR Compressions: 55 points (based on accuracy %)
		- 15/15 Perfect = 55 pts
		- Each miss reduces proportionally
	- Defibrillator: 30 points
		- Clear: 15 pts (0 if missed)
		- Shock timing: 15 pts (0 if missed)
	- Total possible: 100 points
	- Pass threshold: 50 points (need at least half right)
	
	Workspace Setup Required:
		PatientBed_03/
		├── InteractPoint           (Part — proximity trigger)
		├── HeartMonitor            (Part/Model — the monitor screen on wall)
		├── CodeBlueButton          (Part — emergency button on wall, red)
		├── PatientBody             (Model — the patient on the bed)
		├── PatientSpirit           (Model — transparent clone, initially hidden)
		├── EmergencyLight          (SpotLight/PointLight — red, initially off)
		└── DefibrillatorPad        (Part/Model — AED pads on crash cart)
]]

local Room3_CodeBlue = {}

Room3_CodeBlue.Config = {
	id = "CODEBLUE_03",
	title = "Code Blue Emergency",
	patientName = "Ms. Chen",
	location = "PatientBed_03",
	mechanic = "CODE_BLUE", -- identifies the gameplay type

	briefing = "Ms. Chen, 55, was admitted for pneumonia and has been stable. You're doing a routine vitals check. Monitor her heart rate on the screen...",

	vitals = {
		heartRate = "78 bpm (normal)",
		bloodPressure = "118/76 mmHg (normal)",
		temperature = "101.2°F (fever)",
		respiration = "18 breaths/min (normal)",
		oxygenSat = "96% (normal)",
	},

	-- Phase timing
	phases = {
		calm = {
			duration = 4, -- seconds of normal monitoring
			heartRate = 78,
			message = "Monitor Ms. Chen's vitals...",
		},
		deterioration = {
			duration = 3, -- seconds of heart rate dropping
			heartRateSequence = { 72, 65, 58, 40, 0 }, -- drops to flatline
			warningMessage = "⚠ HEART RATE DROPPING",
			flatlineMessage = "⚠ FLATLINE DETECTED",
		},
		callCode = {
			timeWindow = 5, -- seconds to hit the button
			points = 15,
			prompt = "HIT THE CODE BLUE BUTTON!",
			successFeedback = "Code Blue called! Emergency team notified.",
			failFeedback = "Too slow! Delayed response costs critical seconds.",
		},
		cpr = {
			targetBPM = 110, -- compressions per minute target
			targetCompressions = 15, -- need this many good ones
			timeLimit = 20, -- seconds to complete
			totalPoints = 55,
			-- Timing windows (in milliseconds from beat center)
			perfectWindow = 80,  -- ±80ms = Perfect
			goodWindow = 160,    -- ±160ms = Good
			-- outside goodWindow = Miss
			perfectPoints = 3.67, -- 55 / 15 = ~3.67 per perfect
			goodPoints = 2.5,
			missPoints = 0,
		},
		defibrillator = {
			clearTimeWindow = 3, -- seconds to click Clear
			clearPoints = 15,
			-- Shock timing: a bar moves back and forth, click when in green zone
			shockBarSpeed = 2.0, -- cycles per second
			shockGreenZonePercent = 0.3, -- 30% of the bar is the target
			shockPoints = 15,
			clearPrompt = "CLEAR THE PATIENT!",
			shockPrompt = "SHOCK — Hit it in the green zone!",
		},
	},

	-- Pass/fail threshold
	passThreshold = 50, -- out of 100

	-- Outcome messages
	successTitle = "PATIENT STABILIZED",
	successMessage = "Ms. Chen's heartbeat has returned to normal sinus rhythm. Your quick response, effective CPR, and proper defibrillation saved her life. This is what emergency nursing looks like.",

	failureTitle = "PATIENT LOST",
	failureMessage = "Despite your efforts, Ms. Chen could not be resuscitated. In emergency situations, every second and every compression counts. Review BLS protocol and try again.",

	-- Spirit float animation config
	spiritFloat = {
		riseHeight = 20, -- studs above bed
		riseDuration = 4, -- seconds to float up
		fadeStart = 0.3, -- transparency at start
		fadeEnd = 0.9, -- transparency at end
	},
}

-- CPR Rhythm calculation helpers
function Room3_CodeBlue.GetBeatInterval(): number
	-- Time between beats in seconds at target BPM
	return 60 / Room3_CodeBlue.Config.phases.cpr.targetBPM
end

function Room3_CodeBlue.GetConfig()
	return Room3_CodeBlue.Config
end

return Room3_CodeBlue
