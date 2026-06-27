--[[
	Room1_Triage.luau
	Module: ReplicatedStorage/NurseWorld/Room1_Triage
	
	ROOM 1 — Nurse's Office — Patient File Review
	3 patient files, 1 question each
	
	Each file has:
		- Patient name, age, info
		- Vitals
		- Briefing/history
		- 1 clinical question with 3 choices
]]

local Room1_Triage = {}

Room1_Triage.Config = {
	id = "TRIAGE_01",
	title = "Patient File Review",
	mechanic = "FILES",

	files = {
		------------------------------------------------------
		-- FILE 1: Mrs. Robinson — Chest tightness + triage
		------------------------------------------------------
		{
			patientName = "Mrs. Robinson, 67",
			briefing = "Presented with chest tightness, mild dizziness, and a swollen right ankle. History of hypertension and type 2 diabetes. Currently on Lisinopril 10mg daily. Reports the chest tightness started 2 hours ago and describes it as 'pressure, not sharp.' No prior cardiac events on record.",
			vitals = {
				heartRate = "102 bpm (elevated)",
				bloodPressure = "158/94 mmHg (high)",
				temperature = "98.4°F (normal)",
				respiration = "22 breaths/min (slightly elevated)",
				oxygenSat = "94% (borderline low)",
			},
			question = {
				prompt = "Based on this patient's file, what should be your FIRST priority?",
				choices = {
					{
						text = "Focus on the swollen ankle — it could indicate a fracture or DVT",
						isCorrect = false,
						feedback = "The swollen ankle is concerning but not immediately life-threatening. With chest tightness, borderline O2 saturation, and elevated heart rate, airway and breathing take priority using the ABC framework.",
						deduction = 33,
					},
					{
						text = "Address the chest tightness and monitor oxygen levels immediately",
						isCorrect = true,
						feedback = "Correct! Chest tightness combined with low O2 saturation and elevated heart rate in a 67-year-old with hypertension suggests a potential cardiac or respiratory emergency. ABC (Airway, Breathing, Circulation) always comes first.",
						deduction = 0,
					},
					{
						text = "Administer blood pressure medication to bring down the 158/94 reading",
						isCorrect = false,
						feedback = "Treating blood pressure without a full assessment of the chest tightness could mask a cardiac event. You must evaluate the primary complaint before treating secondary findings.",
						deduction = 33,
					},
				},
			},
		},

		------------------------------------------------------
		-- FILE 2: Mr. Alvarez — Post-surgical medication
		------------------------------------------------------
		{
			patientName = "Mr. Alvarez, 45",
			briefing = "Day 2 post-appendectomy. Recovering well, ambulating independently. Prescribed Hydrocodone 5mg oral every 6 hours PRN for pain. Reports pain level of 6/10. Last dose was 7 hours ago. Allergies: Penicillin (rash). No known drug interactions with current medications.",
			vitals = {
				heartRate = "78 bpm (normal)",
				bloodPressure = "124/80 mmHg (normal)",
				temperature = "99.1°F (slightly elevated)",
				respiration = "16 breaths/min (normal)",
				oxygenSat = "98% (normal)",
			},
			question = {
				prompt = "Before administering Mr. Alvarez's pain medication, what is the MOST critical safety step?",
				choices = {
					{
						text = "Ask him 'Are you Mr. Alvarez?' and give the medication if he confirms",
						isCorrect = false,
						feedback = "A yes/no question is unreliable — patients may be confused or drowsy post-surgery. The two-identifier method (full name + date of birth verified against the chart) is the safety standard.",
						deduction = 33,
					},
					{
						text = "Check the bed number matches the chart and proceed",
						isCorrect = false,
						feedback = "Bed numbers are NOT patient identifiers. Patients can be moved between beds. You must use two patient-specific identifiers: full name and date of birth, verified against the medical record.",
						deduction = 33,
					},
					{
						text = "Have him state his full name and date of birth, then verify against his chart and wristband",
						isCorrect = true,
						feedback = "Correct! The two-identifier method (full name + DOB) verified against the chart is the gold standard for patient safety. This prevents medication errors, which are a leading cause of hospital harm.",
						deduction = 0,
					},
				},
			},
		},

		------------------------------------------------------
		-- FILE 3: Ms. Chen — Pneumonia monitoring
		------------------------------------------------------
		{
			patientName = "Ms. Chen, 55",
			briefing = "Admitted 2 days ago for community-acquired pneumonia. On IV antibiotics (Azithromycin). Has been stable and improving — fever trending down, appetite returning. Scheduled for possible discharge tomorrow pending physician review. History of asthma (well-controlled).",
			vitals = {
				heartRate = "88 bpm (normal)",
				bloodPressure = "118/76 mmHg (normal)",
				temperature = "101.2°F (fever, down from 103°F on admission)",
				respiration = "20 breaths/min (normal)",
				oxygenSat = "96% (acceptable)",
			},
			question = {
				prompt = "Ms. Chen's temperature is still elevated at 101.2°F but trending downward. The physician asks for your assessment. What do you report?",
				choices = {
					{
						text = "She's fine — her fever is going down so the antibiotics are working. Recommend discharge today.",
						isCorrect = false,
						feedback = "While the trend is positive, recommending discharge while the patient still has a fever is premature. Nurses should report objective data and trends, not make discharge decisions — that's the physician's role.",
						deduction = 33,
					},
					{
						text = "Report the vital sign trends, current symptoms, and patient's subjective improvement using SBAR format",
						isCorrect = true,
						feedback = "Correct! SBAR (Situation, Background, Assessment, Recommendation) gives the physician a clear, structured picture. Report: fever trending down from 103 to 101.2, improving appetite, stable vitals. Let the physician decide on discharge timing.",
						deduction = 0,
					},
					{
						text = "Tell the physician her vitals are normal and she's ready to go home",
						isCorrect = false,
						feedback = "101.2°F is NOT normal — it's still a fever. Reporting inaccurate information could lead to premature discharge. Always report exact values and let the physician interpret them.",
						deduction = 33,
					},
				},
			},
		},
	},
}

function Room1_Triage.GetConfig()
	return Room1_Triage.Config
end

function Room1_Triage.GetFileCount()
	return #Room1_Triage.Config.files
end

function Room1_Triage.GetFile(index)
	return Room1_Triage.Config.files[index]
end

return Room1_Triage
