"use strict";

const $ = selector => document.querySelector(selector);
const state = { bloom: { viewDay: null, recordDay: null, keyElements: new Map(), layoutBuilt: false, data: null } };

function escapeHtml(value) {
  return String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#039;");
}

function setNotice(message = "", kind = "") {
  const element = $("#inputbloom_notice");
  element.textContent = message;
  element.className = `notice ${kind}`.trim();
  element.classList.toggle("hidden", !message);
}

function setStatus(kind, text) {
  const badge = $("#inputbloom_badge");
  badge.className = `header-status ${kind}`;
  badge.textContent = text;
}

function updateNavigation() {
  const { viewDay, recordDay } = state.bloom;
  $("#bloom_prev").disabled = !viewDay;
  $("#bloom_today").disabled = !viewDay || viewDay === recordDay;
  $("#bloom_next").disabled = !viewDay || viewDay >= recordDay;
}

function addDays(day, offset) {
  const [year, month, value] = day.split("-").map(Number);
  const date = new Date(year, month - 1, value + offset);
  return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-");
}

function keyboardBloomColor(count) {
  if (count <= 0) return "#292c2b";
  if (count <= 49) return "#3b292a";
  if (count <= 149) return "#522b2c";
  if (count <= 349) return "#713031";
  if (count <= 699) return "#963735";
  if (count <= 1199) return "#bb413c";
  if (count <= 1999) return "#d9574b";
  if (count <= 3999) return "#e9725f";
  return "#ef9279";
}

function mouseBloomColor(count) {
  if (count <= 0) return "#292c2b";
  if (count <= 99) return "#3b292a";
  if (count <= 299) return "#522b2c";
  if (count <= 799) return "#713031";
  if (count <= 1499) return "#963735";
  if (count <= 2999) return "#bb413c";
  if (count <= 5999) return "#d9574b";
  if (count <= 9999) return "#e9725f";
  return "#ef9279";
}

function niceTrendMax(value) {
  if (value <= 0) return 10;
  if (value <= 50) return Math.ceil(value / 10) * 10;
  if (value <= 500) return Math.ceil(value / 50) * 50;
  if (value <= 2000) return Math.ceil(value / 100) * 100;
  if (value <= 5000) return Math.ceil(value / 250) * 250;
  return Math.ceil(value / 500) * 500;
}

function buildBloomLayout(layout) {
  if (state.bloom.layoutBuilt) return;
  const board = $("#bloom_board");
  board.querySelectorAll(".bloom-key").forEach(key => key.remove());
  state.bloom.keyElements.clear();
  for (const spec of layout) {
    const key = document.createElement("div");
    key.className = `bloom-key ${spec.cls || ""}`;
    key.dataset.key = spec.key;
    key.style.cssText = `left:${spec.x}px;top:${spec.y}px;width:${spec.w}px;height:${spec.h}px;`;
    key.innerHTML = `<span class="key-label">${escapeHtml(spec.label).replaceAll("\n", "<br>")}</span><span class="key-count">0</span>`;
    board.appendChild(key);
    state.bloom.keyElements.set(spec.key, key);
  }
  state.bloom.layoutBuilt = true;
  resizeBloomBoard();
}

function resizeBloomBoard() {
  const viewport = $("#bloom_canvas_viewport");
  const canvas = $("#bloom_canvas");
  const wrap = $("#bloom_canvas_wrap");
  if (!viewport || !canvas || !wrap) return;
  const scale = Math.min(1, Math.max(.45, (viewport.clientWidth - 2) / 1872));
  canvas.style.transform = `scale(${scale})`;
  wrap.style.width = `${Math.ceil(1872 * scale)}px`;
  wrap.style.height = `${Math.ceil(848 * scale)}px`;
}

function renderBloomTrend(trend) {
  const width = 1190, height = 92, left = 34, right = 8, top = 8, bottom = 14;
  const plotWidth = width - left - right;
  const plotHeight = height - top - bottom;
  const base = top + plotHeight;
  const scaleMax = niceTrendMax(Math.max(...trend.map(item => item.total), 0));
  const points = trend.map((item, index) => {
    const x = left + index * plotWidth / Math.max(1, trend.length - 1);
    const y = base - item.total / scaleMax * plotHeight;
    return { ...item, x, y };
  });
  const polyline = points.map(point => `${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(" ");
  const dots = points.map((point, index) => {
    const selected = index === points.length - 1;
    return `<circle cx="${point.x.toFixed(1)}" cy="${point.y.toFixed(1)}" r="${selected ? 5 : 3}" fill="${selected ? "#f2a088" : "#cf5c55"}" stroke="#292c2b" stroke-width="2"><title>${escapeHtml(point.day)} | ${point.total.toLocaleString()}</title></circle>`;
  }).join("");
  $("#bloom_trend_chart").innerHTML = `
    <div class="bloom-trend-plot">
      <div class="bloom-trend-grid top"></div><div class="bloom-trend-grid mid"></div><div class="bloom-trend-grid base"></div>
      <div class="bloom-trend-scale top">${scaleMax.toLocaleString()}</div><div class="bloom-trend-scale base">0</div>
      <svg class="bloom-trend-svg" viewBox="0 0 ${width} ${height}" role="img" aria-label="30 day activity trend">
        <polyline fill="none" stroke="#d76b61" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" points="${polyline}"></polyline>
        ${dots}
      </svg>
    </div>`;
}

function renderBloom(payload) {
  state.bloom.viewDay = payload.viewDay;
  state.bloom.recordDay = payload.recordDay;
  for (const [keyName, element] of state.bloom.keyElements) {
    const count = payload.keys[keyName] || 0;
    element.style.backgroundColor = keyboardBloomColor(count);
    element.title = `${keyName}: ${count.toLocaleString()}`;
    element.querySelector(".key-count").textContent = count.toLocaleString();
  }
  for (const [selector, button] of [["#mouse_left", "LButton"], ["#mouse_right", "RButton"]]) {
    const count = payload.mouse[button] || 0;
    $(selector).style.backgroundColor = mouseBloomColor(count);
    $(selector).title = `${button}: ${count.toLocaleString()}`;
    $(`${selector} b`).textContent = count.toLocaleString();
  }
  $("#bloom_trend_focus").textContent = payload.viewDay;
  $("#bloom_trend_range").textContent = `Past 30 days ending ${payload.viewDay}`;
  $("#bloom_trend_total").textContent = payload.metrics.total.toLocaleString();
  $("#bloom_trend_split").textContent = `Keyboard ${payload.metrics.keyboard.toLocaleString()} | Mouse ${payload.metrics.mouse.toLocaleString()}`;
  $("#bloom_trend_start").textContent = payload.trend[0]?.day || "--";
  $("#bloom_trend_end").textContent = payload.viewDay;
  renderBloomTrend(payload.trend);
}

function showDay(day) {
  const data = state.bloom.data;
  if (!data) return;
  const selected = day > data.recordDay ? data.recordDay : day;
  const counts = data.days[selected] || { keys: {}, mouse: {} };
  const metrics = counts => {
    const keyboard = Object.values(counts.keys).reduce((sum, count) => sum + count, 0);
    const mouse = Object.values(counts.mouse).reduce((sum, count) => sum + count, 0);
    return { keyboard, mouse, total: keyboard + mouse };
  };
  const trend = Array.from({ length: 30 }, (_, index) => {
    const date = addDays(selected, index - 29);
    return { day: date, ...metrics(data.days[date] || { keys: {}, mouse: {} }) };
  });
  renderBloom({ viewDay: selected, recordDay: data.recordDay, ...counts, metrics: metrics(counts), trend });
  updateNavigation();
}

window.updateInputBloom = data => {
  state.bloom.data = data;
  buildBloomLayout(data.layout);
  showDay(state.bloom.viewDay || data.recordDay);
  if (data.monitor.error) {
    setStatus("failed", "monitor unavailable");
    setNotice(data.monitor.error, "error");
  } else {
    setStatus(data.monitor.active ? "connected" : "disabled", data.monitor.active ? "monitoring" : "stopped");
    setNotice();
  }
};

let loading = false;
function refreshData() {
  if (loading) return;
  loading = true;
  const script = document.createElement("script");
  script.src = `.runtime/data.js?${Date.now()}`;
  script.onload = () => { loading = false; script.remove(); };
  script.onerror = () => {
    loading = false;
    script.remove();
    clearInterval(refreshTimer);
    setStatus("disabled", "stopped");
    setNotice("Start InputBloom to record activity.");
  };
  document.head.appendChild(script);
}

$("#bloom_prev").addEventListener("click", () => { if (state.bloom.viewDay) showDay(addDays(state.bloom.viewDay, -1)); });
$("#bloom_today").addEventListener("click", () => { if (state.bloom.recordDay) showDay(state.bloom.recordDay); });
$("#bloom_next").addEventListener("click", () => {
  if (state.bloom.viewDay && state.bloom.viewDay < state.bloom.recordDay) showDay(addDays(state.bloom.viewDay, 1));
});
window.addEventListener("resize", resizeBloomBoard);
const refreshTimer = setInterval(refreshData, 1800);
refreshData();
