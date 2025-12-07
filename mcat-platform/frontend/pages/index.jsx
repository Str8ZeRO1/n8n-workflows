import { useState, useEffect } from "react";
import "../styles/globals.css";

export default function QuestionPlayer() {
  const [selected, setSelected] = useState(null);
  const [response, setResponse] = useState(null);
  const [timeStart, setTimeStart] = useState(null);
  const [highlights, setHighlights] = useState([]);
  const [eliminatedOptions, setEliminatedOptions] = useState([]);
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(false);
  const [userTier, setUserTier] = useState("premium"); // Change to test different tiers

  // n8n webhook URL (or direct FastAPI if testing without n8n)
  const webhookUrl = "http://localhost:5678/webhook/mcat/submit-answer";
  // Alternative: Direct to FastAPI
  // const webhookUrl = "http://localhost:8000/inference/analyze_attempt";

  const question = {
    id: "q-biochem-001",
    stem: "A researcher adds a competitive inhibitor to an enzyme assay. Which kinetic parameter will increase?",
    passage: `Competitive inhibitors bind to the active site of an enzyme, preventing substrate binding. They can be overcome by increasing substrate concentration. The Michaelis-Menten equation describes the relationship between substrate concentration and reaction velocity.`,
    options: {
      A: "Vmax",
      B: "Km (apparent)",
      C: "kcat",
      D: "Enzyme concentration"
    }
  };

  const addEvent = (type, value = null) => {
    const offset = timeStart ? Date.now() - timeStart : 0;
    setEvents([...events, { type, value, timestamp_offset_ms: offset }]);
  };

  const startTimer = () => {
    if (!timeStart) {
      setTimeStart(Date.now());
    }
  };

  const toggleHighlight = (text) => {
    setHighlights((h) => {
      const newHighlights = h.includes(text) ? h.filter(x => x !== text) : [...h, text];
      addEvent("highlight", text);
      return newHighlights;
    });
  };

  const toggleEliminate = (option) => {
    setEliminatedOptions((opts) => {
      const newOpts = opts.includes(option) ? opts.filter(x => x !== option) : [...opts, option];
      addEvent("eliminate_option", option);
      return newOpts;
    });
  };

  const handleSelectAnswer = (option) => {
    if (selected !== option) {
      if (selected) {
        addEvent("change_answer", `${selected} -> ${option}`);
      }
      setSelected(option);
      startTimer();
    }
  };

  const submit = async () => {
    if (!selected) {
      alert("Please select an answer first.");
      return;
    }

    setLoading(true);
    const time_ms = Date.now() - (timeStart || Date.now());

    const payload = {
      user_id: "550e8400-e29b-41d4-a716-446655440000", // Demo user UUID
      question_id: question.id,
      answer: selected,
      time_ms,
      events,
      user_tier: userTier,
      confidence_level: 3
    };

    try {
      const res = await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      }

      const data = await res.json();
      setResponse(data);
    } catch (err) {
      console.error("Submission error:", err);
      alert(`Error: ${err.message}\n\nMake sure n8n or FastAPI is running.`);
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setSelected(null);
    setResponse(null);
    setTimeStart(null);
    setHighlights([]);
    setEliminatedOptions([]);
    setEvents([]);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-8 px-4">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-6 text-center">
          <h1 className="text-4xl font-bold text-gray-800 mb-2">MCAT Question Player</h1>
          <p className="text-gray-600">AI-Powered Reasoning Analysis Demo</p>
          <div className="mt-4 flex justify-center gap-2">
            <span className="text-sm font-medium text-gray-700">User Tier:</span>
            <select
              value={userTier}
              onChange={(e) => setUserTier(e.target.value)}
              className="text-sm border border-gray-300 rounded px-2 py-1"
            >
              <option value="free">Free</option>
              <option value="pro">Pro</option>
              <option value="premium">Premium</option>
            </select>
          </div>
        </div>

        {/* Question Card */}
        <div className="card mb-6">
          <div className="mb-4">
            <h2 className="text-sm font-semibold text-gray-500 uppercase mb-2">Passage</h2>
            <div className="bg-gray-50 p-4 rounded-lg border border-gray-200">
              <p className="text-gray-700 leading-relaxed">{question.passage}</p>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                onClick={() => toggleHighlight("inhibitor")}
                className={`text-xs px-3 py-1 rounded ${
                  highlights.includes("inhibitor")
                    ? "bg-yellow-300 text-yellow-900"
                    : "bg-gray-200 text-gray-700"
                }`}
              >
                💡 Highlight: "inhibitor"
              </button>
              <button
                onClick={() => toggleHighlight("competitive")}
                className={`text-xs px-3 py-1 rounded ${
                  highlights.includes("competitive")
                    ? "bg-yellow-300 text-yellow-900"
                    : "bg-gray-200 text-gray-700"
                }`}
              >
                💡 Highlight: "competitive"
              </button>
              <button
                onClick={() => toggleHighlight("Km")}
                className={`text-xs px-3 py-1 rounded ${
                  highlights.includes("Km")
                    ? "bg-yellow-300 text-yellow-900"
                    : "bg-gray-200 text-gray-700"
                }`}
              >
                💡 Highlight: "Km"
              </button>
            </div>
          </div>

          <div className="mb-4">
            <h2 className="text-lg font-bold text-gray-800 mb-3">{question.stem}</h2>
          </div>

          {/* Options */}
          <div className="space-y-3">
            {Object.entries(question.options).map(([key, value]) => (
              <div
                key={key}
                className={`flex items-center gap-3 p-3 rounded-lg border-2 transition-all ${
                  eliminatedOptions.includes(key)
                    ? "border-red-300 bg-red-50 opacity-50"
                    : selected === key
                    ? "border-blue-500 bg-blue-50"
                    : "border-gray-300 bg-white hover:border-gray-400"
                }`}
              >
                <input
                  type="radio"
                  name="answer"
                  value={key}
                  checked={selected === key}
                  onChange={() => handleSelectAnswer(key)}
                  className="w-4 h-4"
                  disabled={eliminatedOptions.includes(key)}
                />
                <label className="flex-1 cursor-pointer">
                  <span className="font-semibold text-gray-800">{key}.</span>{" "}
                  <span className="text-gray-700">{value}</span>
                </label>
                <button
                  onClick={() => toggleEliminate(key)}
                  className={`text-xs px-2 py-1 rounded ${
                    eliminatedOptions.includes(key)
                      ? "bg-red-200 text-red-800"
                      : "bg-gray-200 text-gray-600 hover:bg-red-100"
                  }`}
                >
                  {eliminatedOptions.includes(key) ? "✓ Eliminated" : "❌ Eliminate"}
                </button>
              </div>
            ))}
          </div>

          {/* Submit Button */}
          <div className="mt-6 flex gap-3">
            <button
              onClick={submit}
              disabled={loading || !selected}
              className={`btn-primary flex-1 ${
                loading || !selected ? "opacity-50 cursor-not-allowed" : ""
              }`}
            >
              {loading ? "Analyzing..." : "Submit Answer"}
            </button>
            <button onClick={reset} className="btn-secondary">
              Reset
            </button>
          </div>
        </div>

        {/* Response Overlay */}
        {response && (
          <div className="card bg-gradient-to-br from-green-50 to-blue-50 border-2 border-green-300">
            <div className="mb-4">
              <h2 className="text-2xl font-bold mb-2">
                {response.correct ? (
                  <span className="text-green-600">✓ Correct!</span>
                ) : (
                  <span className="text-red-600">✗ Incorrect</span>
                )}
              </h2>
              <p className="text-gray-700">
                Correct answer: <span className="font-bold text-blue-600">{response.correct_answer}</span>
              </p>
            </div>

            {/* Diagnoses */}
            {response.diagnoses && response.diagnoses.length > 0 && (
              <div className="mb-4">
                <h3 className="text-lg font-semibold text-gray-800 mb-2">🧠 Reasoning Analysis</h3>
                <div className="space-y-2">
                  {response.diagnoses.map((diag, idx) => (
                    <div key={idx} className="bg-white p-3 rounded-lg border border-gray-200">
                      <div className="flex items-center justify-between mb-1">
                        <span className="font-semibold text-gray-800">{diag.name.replace(/_/g, " ").toUpperCase()}</span>
                        <span className="text-sm font-medium text-blue-600">{Math.round(diag.confidence * 100)}% confidence</span>
                      </div>
                      <p className="text-sm text-gray-600">{diag.explanation}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Overlay */}
            {response.overlay && (
              <div className="mb-4">
                <h3 className="text-lg font-semibold text-gray-800 mb-2">
                  💡 Adaptive Overlay (Level {response.overlay.level})
                </h3>
                <div className="bg-white p-4 rounded-lg border border-blue-200">
                  <p className="text-blue-700 font-medium mb-3">{response.overlay.insight}</p>
                  <h4 className="text-sm font-semibold text-gray-700 mb-2">Reasoning Steps:</h4>
                  <ol className="list-decimal list-inside space-y-1">
                    {response.overlay.steps.map((step, idx) => (
                      <li key={idx} className="text-sm text-gray-700">{step}</li>
                    ))}
                  </ol>
                </div>
              </div>
            )}

            {/* Micro-Drills */}
            {response.drills && response.drills.length > 0 && (
              <div>
                <h3 className="text-lg font-semibold text-gray-800 mb-2">🎯 Micro-Drills</h3>
                <div className="space-y-2">
                  {response.drills.map((drill, idx) => (
                    <details key={idx} className="bg-white p-3 rounded-lg border border-gray-200">
                      <summary className="font-medium text-gray-800 cursor-pointer">
                        Drill {idx + 1}: {drill.prompt}
                      </summary>
                      <p className="mt-2 text-sm text-green-700 pl-4">✓ {drill.answer}</p>
                    </details>
                  ))}
                </div>
              </div>
            )}

            {/* Debug Info */}
            {response.debug && (
              <details className="mt-4 text-xs text-gray-500">
                <summary className="cursor-pointer font-medium">Debug Info</summary>
                <pre className="mt-2 bg-gray-100 p-2 rounded overflow-x-auto">
                  {JSON.stringify(response.debug, null, 2)}
                </pre>
              </details>
            )}
          </div>
        )}

        {/* Event Log (Debug) */}
        {events.length > 0 && !response && (
          <details className="mt-4 text-xs">
            <summary className="cursor-pointer font-medium text-gray-600">
              Event Log ({events.length} events)
            </summary>
            <div className="mt-2 bg-white p-3 rounded border border-gray-200 max-h-40 overflow-y-auto">
              {events.map((evt, idx) => (
                <div key={idx} className="text-gray-600">
                  [{evt.timestamp_offset_ms}ms] {evt.type}: {evt.value || "N/A"}
                </div>
              ))}
            </div>
          </details>
        )}
      </div>
    </div>
  );
}
