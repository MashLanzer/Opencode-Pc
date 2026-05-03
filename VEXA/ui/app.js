/* VEXA UI — Neural Interface */

const HOST    = window.location.hostname || "localhost";
const WS_URL  = `ws://${HOST}:8766`;
const API_URL = `http://${HOST}:8765`;

// ── State colors ─────────────────────────────────────────────────────
const STATE_CFG = {
  IDLE:       { r: 0,   g: 212, b: 255, speed: 0.25, chaos: 0.00, label: "EN ESPERA"    },
  LISTENING:  { r: 0,   g: 255, b: 157, speed: 0.80, chaos: 0.15, label: "ESCUCHANDO"   },
  THINKING:   { r: 255, g: 170, b: 0,   speed: 1.60, chaos: 0.90, label: "PROCESANDO"   },
  SPEAKING:   { r: 176, g: 96,  b: 255, speed: 1.00, chaos: 0.25, label: "RESPONDIENDO" },
  PC_CONTROL: { r: 68,  g: 136, b: 255, speed: 0.50, chaos: 0.05, label: "CONTROL PC"   },
  AGENT:      { r: 255, g: 107, b: 53,  speed: 1.20, chaos: 0.50, label: "MODO AGENTE"  },
};

// ── Background starfield ──────────────────────────────────────────────
(function initBg() {
  const canvas = document.getElementById("bg-canvas");
  const ctx    = canvas.getContext("2d");
  let W, H, stars = [];

  function resize() {
    W = canvas.width  = window.innerWidth;
    H = canvas.height = window.innerHeight;
    stars = Array.from({ length: 120 }, () => ({
      x: Math.random() * W,
      y: Math.random() * H,
      r: Math.random() * 1.2,
      a: Math.random() * 0.6 + 0.1,
      v: Math.random() * 0.3 + 0.05,
    }));
  }
  resize();
  window.addEventListener("resize", resize);

  function drawBg() {
    ctx.clearRect(0, 0, W, H);
    stars.forEach(s => {
      s.a += Math.sin(Date.now() * s.v * 0.001) * 0.003;
      s.a = Math.max(0.05, Math.min(0.7, s.a));
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(180,220,255,${s.a.toFixed(2)})`;
      ctx.fill();
    });
    requestAnimationFrame(drawBg);
  }
  drawBg();
})();

// ── Orb particle system ───────────────────────────────────────────────
const orbCanvas  = document.getElementById("sphere");
const orbCtx     = orbCanvas.getContext("2d");
const OW = orbCanvas.width, OH = orbCanvas.height;
const CX = OW / 2, CY = OH / 2;
const NUM_P  = 200;
const RADIUS = 100;

let currentState = "IDLE";
let targetCfg    = { ...STATE_CFG.IDLE };
let liveCfg      = { r: 0, g: 212, b: 255, speed: 0.25, chaos: 0 };
let orbT         = 0;

const particles = Array.from({ length: NUM_P }, () => ({
  theta: Math.acos(2 * Math.random() - 1),
  phi:   Math.random() * Math.PI * 2,
  phase: Math.random() * Math.PI * 2,
  size:  Math.random() * 1.8 + 0.4,
  spd:   Math.random() * 0.5 + 0.08,
}));

function lerp(a, b, k) { return a + (b - a) * k; }

function drawOrb() {
  orbCtx.clearRect(0, 0, OW, OH);

  liveCfg.r     = lerp(liveCfg.r,     targetCfg.r,     0.04);
  liveCfg.g     = lerp(liveCfg.g,     targetCfg.g,     0.04);
  liveCfg.b     = lerp(liveCfg.b,     targetCfg.b,     0.04);
  liveCfg.speed = lerp(liveCfg.speed, targetCfg.speed, 0.03);
  liveCfg.chaos = lerp(liveCfg.chaos, targetCfg.chaos, 0.03);

  const { r, g, b } = liveCfg;

  // Core glow
  const grd = orbCtx.createRadialGradient(CX, CY, 0, CX, CY, 55);
  grd.addColorStop(0,   `rgba(${r},${g},${b},0.22)`);
  grd.addColorStop(0.5, `rgba(${r},${g},${b},0.07)`);
  grd.addColorStop(1,   `rgba(${r},${g},${b},0)`);
  orbCtx.beginPath();
  orbCtx.arc(CX, CY, 55, 0, Math.PI * 2);
  orbCtx.fillStyle = grd;
  orbCtx.fill();

  // LISTENING rings
  if (currentState === "LISTENING") {
    for (let i = 1; i <= 3; i++) {
      const rr   = 50 + (orbT * 90 + i * 36) % 120;
      const alpha = Math.max(0, 0.35 - rr / 250);
      orbCtx.beginPath();
      orbCtx.arc(CX, CY, rr, 0, Math.PI * 2);
      orbCtx.strokeStyle = `rgba(${r},${g},${b},${alpha})`;
      orbCtx.lineWidth = 1.5;
      orbCtx.stroke();
    }
  }

  // SPEAKING waves
  if (currentState === "SPEAKING") {
    for (let i = 0; i < 6; i++) {
      const wave = Math.sin(orbT * 5 + i * 1.1) * 12;
      const wr   = 70 + i * 18 + wave;
      const alpha = Math.max(0, 0.18 - i * 0.025);
      orbCtx.beginPath();
      orbCtx.arc(CX, CY, wr, 0, Math.PI * 2);
      orbCtx.strokeStyle = `rgba(${r},${g},${b},${alpha})`;
      orbCtx.lineWidth = 1.2;
      orbCtx.stroke();
    }
  }

  // THINKING scan
  if (currentState === "THINKING") {
    const angle = orbT * 2.5;
    const x2 = CX + 90 * Math.cos(angle);
    const y2 = CY + 90 * Math.sin(angle);
    const scanGrd = orbCtx.createLinearGradient(CX, CY, x2, y2);
    scanGrd.addColorStop(0, `rgba(${r},${g},${b},0)`);
    scanGrd.addColorStop(1, `rgba(${r},${g},${b},0.2)`);
    orbCtx.beginPath();
    orbCtx.moveTo(CX, CY);
    orbCtx.arc(CX, CY, 90, angle - 0.4, angle);
    orbCtx.closePath();
    orbCtx.fillStyle = scanGrd;
    orbCtx.fill();
  }

  // Particles
  particles.forEach(p => {
    p.phi += p.spd * liveCfg.speed * 0.016;
    const co = liveCfg.chaos * Math.sin(orbT * 2.5 + p.phase) * 0.35;
    const th = p.theta + co;
    const ph = p.phi + Math.sin(orbT * 1.8 + p.phase) * liveCfg.chaos * 0.2;

    const x = CX + RADIUS * Math.sin(th) * Math.cos(ph);
    const y = CY + RADIUS * Math.sin(th) * Math.sin(ph) * 0.42;
    const z = Math.cos(th);
    const depth = (z + 1) / 2;
    const alpha = 0.15 + depth * 0.75;
    const ps    = p.size * (0.3 + depth * 0.9);
    const pulse = 1 + Math.sin(orbT * 1.8 + p.phase) * 0.12;

    orbCtx.beginPath();
    orbCtx.arc(x, y, ps * pulse, 0, Math.PI * 2);
    orbCtx.fillStyle = `rgba(${r},${g},${b},${alpha.toFixed(2)})`;
    orbCtx.fill();
  });

  orbT += 0.016;
  requestAnimationFrame(drawOrb);
}
drawOrb();

// ── UI state update ───────────────────────────────────────────────────
function setState(s) {
  if (!STATE_CFG[s]) return;
  currentState = s;
  targetCfg    = STATE_CFG[s];

  document.body.dataset.state = s;
  document.getElementById("state-text").textContent = STATE_CFG[s].label;
  document.getElementById("orb-label").textContent  = STATE_CFG[s].label;

  const mode = { PC_CONTROL: "PC CONTROL", AGENT: "AGENTE", IDLE: "CHAT",
                 LISTENING: "CHAT", THINKING: "CHAT", SPEAKING: "CHAT" };
  document.getElementById("stat-mode").textContent = mode[s] || "CHAT";
}

// ── Chat history ──────────────────────────────────────────────────────
function addMsg(text, type = "vexa") {
  const box = document.getElementById("chat-box");
  const el  = document.createElement("div");
  el.className = `msg ${type}`;
  el.textContent = text;
  box.appendChild(el);
  box.scrollTop = box.scrollHeight;
  while (box.children.length > 60) box.firstChild.remove();
}

function clearChat() {
  const box = document.getElementById("chat-box");
  box.innerHTML = '<div class="msg sys">Historial borrado.</div>';
  sendCommand("limpia el historial");
}

// ── API ───────────────────────────────────────────────────────────────
async function sendCommand(cmd) {
  if (!cmd.trim()) return;
  try {
    await fetch(`${API_URL}/command`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ command: cmd }),
    });
  } catch (e) {
    addMsg("Error: VEXA no responde.", "sys");
  }
}

async function sendState(s) {
  try {
    await fetch(`${API_URL}/state`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({ state: s }),
    });
  } catch (e) {}
}

// ── Input (texto) ─────────────────────────────────────────────────────
function submitText() {
  const input = document.getElementById("cmd-input");
  const text  = input.value.trim();
  if (!text) return;
  addMsg(text, "user");
  sendCommand(text);
  input.value = "";
  input.focus();
}

document.getElementById("cmd-input").addEventListener("keydown", e => {
  if (e.key === "Enter") { e.preventDefault(); submitText(); }
});
document.getElementById("btn-send").addEventListener("click", submitText);

// ── Web Speech (mic en desktop/localhost) ─────────────────────────────
const micBtn  = document.getElementById("mic-btn");
const interim = document.getElementById("interim-text");
let recognition = null, listening = false;
const SR = window.SpeechRecognition || window.webkitSpeechRecognition;

if (SR) {
  recognition = new SR();
  recognition.lang = "es-ES";
  recognition.continuous = false;
  recognition.interimResults = true;

  recognition.onstart  = () => { listening = true;  micBtn.classList.add("recording"); };
  recognition.onend    = () => { listening = false; micBtn.classList.remove("recording"); interim.textContent = ""; };
  recognition.onerror  = () => { listening = false; micBtn.classList.remove("recording"); interim.textContent = ""; };

  recognition.onresult = e => {
    let finalTxt = "", interimTxt = "";
    for (const r of e.results) {
      if (r.isFinal) finalTxt += r[0].transcript;
      else interimTxt += r[0].transcript;
    }
    interim.textContent = interimTxt || finalTxt;
    if (finalTxt) {
      interim.textContent = "";
      addMsg(finalTxt.trim(), "user");
      sendCommand(finalTxt.trim());
    }
  };

  micBtn.addEventListener("click", () => {
    if (listening) recognition.stop();
    else           recognition.start();
  });
} else {
  micBtn.style.opacity = "0.3";
  micBtn.title = "Speech API no soportada en este browser";
}

// ── WebSocket ─────────────────────────────────────────────────────────
let ws = null, reconnTimer = null;

function connectWS() {
  if (ws && ws.readyState < 2) return;
  try { ws = new WebSocket(WS_URL); }
  catch(e) { scheduleRecon(); return; }

  const dot = document.getElementById("ws-indicator");

  ws.onopen = () => {
    dot.classList.add("ok");
    if (reconnTimer) { clearTimeout(reconnTimer); reconnTimer = null; }
    ws.send(JSON.stringify({ type: "get_status" }));
  };

  ws.onmessage = e => {
    try {
      const msg = JSON.parse(e.data);
      if (msg.type === "state_change" || msg.type === "status") {
        setState(msg.state);
      } else if (msg.type === "response") {
        addMsg(msg.text, "vexa");
      }
    } catch(_) {}
  };

  ws.onclose = () => {
    dot.classList.remove("ok");
    scheduleRecon();
  };
}

function scheduleRecon() {
  if (!reconnTimer) reconnTimer = setTimeout(connectWS, 3000);
}

// Poll fallback
setInterval(async () => {
  if (ws && ws.readyState === 1) return;
  try {
    const r = await fetch(`${API_URL}/status`);
    const d = await r.json();
    setState(d.state);
  } catch(_) {}
}, 4000);

// ── Reloj ─────────────────────────────────────────────────────────────
function updateClock() {
  document.getElementById("clock").textContent =
    new Date().toLocaleTimeString("es", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}
updateClock();
setInterval(updateClock, 1000);

// ── Init ──────────────────────────────────────────────────────────────
connectWS();

fetch(`${API_URL}/status`)
  .then(r => r.json())
  .then(d => { setState(d.state); addMsg(`VEXA online — ${d.state}`, "sys"); })
  .catch(() => addMsg("VEXA offline. Iniciala con: ia vexa start", "sys"));
