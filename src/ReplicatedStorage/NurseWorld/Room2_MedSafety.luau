--[[
	Room2_MedSafety.luau
	Module: ReplicatedStorage/NurseWorld/Room2_MedSafety
	
	ROOM 2 — Mr. Alvarez — Medication Administration
	Mechanic: Click objects in the room in the CORRECT ORDER
	
	The player must physically click on objects in the hospital room
	in the proper sequence to safely administer medication.
	
	Correct Order (The 5 Rights + Hygiene):
		1. Hand Sanitizer (wall dispenser) — wash hands first
		2. Patient Wristband — verify patient identity
		3. Medication Chart (clipboard on wall) — check the order
		4. Medication Cart (correct bottle) — select right medication
		5. Patient (administer medication)
	
	If the player clicks out of order, they get a warning and lose points.
	If they click 3 wrong objects, they fail the scenario.
	
	Workspace Setup Required:
		PatientBed_02/
		├── InteractPoint          (Part — proximity trigger)
		├── HandSanitizer          (Part/Model — clickable, wall-mounted)
		├── PatientWristband       (Part — on the patient's arm area)
		├── MedicationChart        (Part/Model — clipboard on wall or bedside)
		├── MedicationCart          (Part/Model — cart with bottles)
		└── PatientAdminister      (Part — the patient/bed area for final step)
		
	Each clickable object needs:
		- A ClickDetector child (created by this script or manually)
		- A BillboardGui that shows a subtle glow/highlight when active
]]

local Room2_MedSafety = {}

Room2_MedSafety.Config = {
	id = "MEDSAFETY_02",
	title = "Medication Administration",
	patientName = "Mr. Alvarez",
	location = "PatientBed_02",
	mechanic = "CLICK_ORDER", -- identifies the gameplay type

	briefing = "Mr. Alvarez, 45, is recovering from surgery and needs his next dose of pain medication. You must follow proper medication administration protocol. Click the correct objects in the room in the RIGHT ORDER to safely administer the medication.",

	vitals = {
		heartRate = "78 bpm (normal)",
		bloodPressure = "124/80 mmHg (normal)",
		temperature = "99.1°F (slightly elevated)",
		respiration = "16 breaths/min (normal)",
		oxygenSat = "98% (normal)",
	},

	-- The correct sequence of objects to click
	steps = {
		{
			objectName = "HandSanitizer",
			label = "Hand Sanitizer",
			instruction = "Always sanitize your hands before patient contact.",
			icon = "🧴",
			correctFeedback = "Good — hands sanitized. Infection control is the first step in any patient interaction.",
			wrongClickFeedback = "Stop! You must sanitize your hands before touching anything. Infection control comes first.",
		},
		{
			objectName = "PatientWristband",
			label = "Patient Wristband",
			instruction = "Verify the patient's identity using two identifiers.",
			icon = "🏷️",
			correctFeedback = "Patient verified — Carlos Alvarez, DOB 03/15/1981. Identity confirmed with two identifiers.",
			wrongClickFeedback = "You need to verify the patient's identity before proceeding. Check the wristband first.",
		},
		{
			objectName = "MedicationChart",
			label = "Medication Chart",
			instruction = "Check the physician's order for drug, dose, route, and time.",
			icon = "📋",
			correctFeedback = "Order confirmed — Hydrocodone 5mg, oral, every 6 hours PRN. Last dose was 7 hours ago. Clear to administer.",
			wrongClickFeedback = "You haven't checked the medication order yet. Always verify the order before touching the medication.",
		},
		{
			objectName = "MedicationCart",
			label = "Medication Cart",
			instruction = "Select the correct medication. Verify drug name, dose, and expiration.",
			icon = "💊",
			correctFeedback = "Hydrocodone 5mg selected. Label matches order. Expiration date valid. This is the right medication.",
			wrongClickFeedback = "You're not ready to select medication yet. Complete the previous steps first.",
		},
		{
			objectName = "PatientAdminister",
			label = "Administer to Patient",
			instruction = "Give the medication to the patient with clear instructions.",
			icon = "🏥",
			correctFeedback = "Medication administered. You explained the drug name, purpose, and side effects to Mr. Alvarez. Excellent patient communication.",
			wrongClickFeedback = "You can't administer yet — you haven't completed all safety checks.",
		},
	},

	-- Scoring
	maxMistakes = 3,           -- 3 wrong clicks = fail
	pointsPerMistake = 33,     -- lose 33 per wrong click

	resultGood = "Perfect medication administration! You followed all 5 Rights and maintained proper infection control. Mr. Alvarez is safe in your care.",
	resultBad = "Medication errors are a leading cause of patient harm. Remember: Hand hygiene → Verify patient → Check order → Select drug → Administer. The sequence saves lives.",
}

function Room2_MedSafety.GetConfig()
	return Room2_MedSafety.Config
end

return Room2_MedSafety
