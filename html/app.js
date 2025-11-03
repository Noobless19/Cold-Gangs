/* ===========================
Global UI state
=========================== */
let gangData = { id: 0, name: "No Gang", tag: "", rank: 0, isLeader: false, bank: 0, money: 0, reputation: 0, max_members: 0, color: "#ff3e3e", logo: "" };
let playerData = { citizenId: "", name: "Unknown", money: 0, rank: 0, isAdmin: false };

let members = [];
let territories = [];
let transactions = [];
let businesses = [];
let vehicles = []; // can also be an object payload for enriched vehicles (see updateVehicles)
let drugFields = [];
let drugLabs = [];
let activeWars = [];
let activeHeists = [];

let currentScreen = "home";
let isOpen = false;
let currencySymbol = "£";

let territoryFilter = "all";
let territorySearch = "";
let lastTerritoryDetails = null;

let currentAdminTab = "gangs";
let adminGangs = [];
let adminPlayers = [];
let adminTerritories = [];
let adminLogs = [];

let bindingsInit = false;
let vehiclesBindingsInit = false;

let currentGangStash = null;
let currentSharedStashes = [];
let selectedSharedStash = null;
let fronts = [];

/* ===========================
NUI Helpers
=========================== */
function postNUI(endpoint, data = {}) {
  fetch(`https://cold-gangs/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data)
  }).catch(() => { });
}

/* ===========================
Utils
=========================== */
function formatMoney(amount) {
  const n = Number(amount || 0);
  const parts = Math.floor(Math.abs(n)).toString().split("");
  let out = "";
  let cnt = 0;
  for (let i = parts.length - 1; i >= 0; i--) {
    out = parts[i] + out;
    cnt++;
    if (cnt === 3 && i !== 0) {
      out = "," + out;
      cnt = 0;
    }
  }
  const prefix = n < 0 ? "-" : "";
  return `${prefix}${currencySymbol}${out}`;
}

function formatDate(ts) {
  if (!ts) return "N/A";
  const d = new Date(ts);
  return d.toLocaleString();
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

function showNotification(title, message, type = "info") {
  const container = document.getElementById("notifications-container");
  if (!container) return;
  const el = document.createElement("div");
  el.className = `notification ${type}`;
  const icons = {
    success: "fa-check-circle",
    error: "fa-exclamation-circle",
    warning: "fa-exclamation-triangle",
    info: "fa-info-circle",
    primary: "fa-info-circle"
  };
  el.innerHTML = `
<div class="notification-icon"><i class="fas ${icons[type] || icons.info}"></i></div>
<div class="notification-content">
<div class="notification-title">${escapeHtml(title)}</div>
<div class="notification-message">${escapeHtml(message)}</div>
</div>
<button class="notification-close" onclick="this.parentElement.remove()"><i class="fas fa-times"></i></button>
`;
  container.appendChild(el);
  setTimeout(() => {
    el.style.animation = "slideUp 0.5s forwards";
    setTimeout(() => el.remove(), 500);
  }, 5000);
}

function updateTime() {
  const now = new Date();
  const el = document.getElementById("sb-clock");
  if (el) el.textContent = now.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" });
}

function openScreen(screenName) {
  currentScreen = screenName;
  document.querySelectorAll(".screen").forEach(s => s.classList.remove("active"));
  const s = document.getElementById(`${screenName}-screen`);
  if (s) s.classList.add("active");
}

function openUI() {
  isOpen = true;
  const container = document.getElementById("tablet");
  if (!container) return;
  container.classList.remove("hidden");
  updateTime();
  if (!window.timeInterval) window.timeInterval = setInterval(updateTime, 60000);
}

function applyCloseUI() {
  isOpen = false;
  const container = document.getElementById("tablet");
  if (container) container.classList.add("hidden");
  currentScreen = "home";
}

function requestCloseUI() {
  postNUI("closeUI");
  applyCloseUI();
}

function showLoading(message = "Loading...") {
  const screen = document.getElementById("loading-screen");
  if (!screen) return;
  const msg = document.getElementById("loading-message");
  if (msg) msg.textContent = message;
  document.querySelectorAll(".screen").forEach(s => s.classList.remove("active"));
  screen.classList.add("active");
  screen.style.display = "flex";
}

function hideLoading() {
  const screen = document.getElementById("loading-screen");
  if (!screen) return;
  screen.classList.remove("active");
  screen.style.display = "none";
  openScreen(currentScreen);
}

/* ===========================
Updaters: Overview
=========================== */
function updateGangInfo() {
  const gangName = document.getElementById("gang-name");
  const gangTag = document.getElementById("gang-tag");
  const bankEl = document.getElementById("gang-bank");
  const repEl = document.getElementById("gang-rep");
  const maxEl = document.getElementById("gang-max");
  const playerRankEl = document.getElementById("player-rank");
  const homeRankEl = document.getElementById("home-player-rank");
  const gangLogo = document.getElementById("gang-logo");
  const adminRank = document.querySelector(".admin-rank");

  if (gangName) gangName.textContent = gangData.name || "No Gang";
  if (gangTag) gangTag.textContent = gangData.tag || "";
  if (bankEl) bankEl.textContent = formatMoney(gangData.bank || 0);
  if (repEl) repEl.textContent = String(gangData.reputation || 0);
  if (maxEl) maxEl.textContent = String(gangData.max_members || 0);

  const myCid = playerData.citizenId || playerData.citizenid || "";
  let effectiveRank = gangData.rank || 0;
  if (!effectiveRank && Array.isArray(members) && myCid) {
    const me = members.find(m => (m.citizenId || m.citizenid) === myCid);
    if (me && me.rank) effectiveRank = me.rank;
  }
  if (playerRankEl) playerRankEl.textContent = String(effectiveRank);
  if (homeRankEl) homeRankEl.textContent = `Rank: ${effectiveRank}`;
  if (gangLogo && gangLogo.style) gangLogo.style.borderColor = gangData.color || "#ff3e3e";
  if (adminRank && adminRank.style) adminRank.style.color = gangData.color || "#ff3e3e";

  const adminApp = document.getElementById("app-admin");
  if (adminApp) {
    if (playerData.isAdmin) adminApp.classList.remove("hidden");
    else adminApp.classList.add("hidden");
  }
  const homeGangChip = document.getElementById("home-gang-chip");
  if (homeGangChip) homeGangChip.textContent = gangData.name || "No Gang";
}

function updateStats() {
  const statMembers = document.getElementById("stat-members");
  const statBank = document.getElementById("stat-bank");
  const bankBalance = document.getElementById("bank-balance");
  const bankCash = document.getElementById("bank-cash");
  const statTerr = document.getElementById("stat-territories");
  const statReputation = document.getElementById("stat-reputation");
  const statFronts = document.getElementById("stat-fronts");

  if (statMembers) statMembers.textContent = members.length;
  if (statBank) statBank.textContent = formatMoney(gangData.bank || 0);
  if (bankBalance) bankBalance.textContent = formatMoney(gangData.bank || 0);
  if (bankCash) bankCash.textContent = formatMoney(playerData.money || 0);
  if (statTerr) {
    const owned = (territories || []).filter(t => t.gangId === gangData.id).length;
    statTerr.textContent = owned;
  }
  if (statReputation) statReputation.textContent = String(gangData.reputation || 0);
}

function updatePlayerInfo() {
  const playerName = document.getElementById("player-name") || document.getElementById("home-player-name");
  if (playerName) playerName.textContent = playerData.name || "Unknown";
}

/* ===========================
Updaters: Lists
=========================== */
function updateMembers() {
  const list = document.getElementById("members-list");
  if (!list) return;
  list.innerHTML = "";
  members.forEach(m => {
    const card = document.createElement("div");
    card.className = "player-card-tablet";
    let actions = "";
    if (gangData.isLeader && !m.isLeader) {
      actions = `
<div style="display:flex; gap:6px;">
<button class="quick-action-btn" style="min-width:auto;padding:8px;" onclick="postNUI('promoteMember', {citizenId: '${m.citizenid || m.citizenId}'})"><i class="fas fa-arrow-up"></i><span>Promote</span></button>
<button class="quick-action-btn" style="min-width:auto;padding:8px;" onclick="postNUI('demoteMember', {citizenId: '${m.citizenid || m.citizenId}'})"><i class="fas fa-arrow-down"></i><span>Demote</span></button>
<button class="quick-action-btn" style="min-width:auto;padding:8px;" onclick="postNUI('kickMember', {citizenId: '${m.citizenid || m.citizenId}'})"><i class="fas fa-user-slash"></i><span>Kick</span></button>
</div>
`;
    }
    card.innerHTML = `
<div class="player-avatar-tablet"><i class="fas fa-user"></i></div>
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(m.name || m.citizenid || m.citizenId)} ${m.isLeader ? '<span class="admin-badge">LEADER</span>' : ""}</div>
<div class="player-details-tablet">
<span>Rank ${m.rank ?? 0}</span>
<span>ID: ${escapeHtml(m.citizenid || m.citizenId)}</span>
</div>
</div>
${actions}
`;
    list.appendChild(card);
  });
}

function updateTransactions() {
  const lists = [document.getElementById("transactions-list"), document.getElementById("tx-list"), document.getElementById("bank-tx-list")].filter(Boolean);
  lists.forEach(list => {
    list.innerHTML = "";
    (transactions || []).slice(0, 10).forEach(tx => {
      const card = document.createElement("div");
      card.className = "player-card-tablet";
      card.style.marginBottom = "8px";
      card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(formatDate(tx.timestamp))}</div>
<div class="player-details-tablet">
<span>${escapeHtml(tx.description || tx.type || "Transaction")}</span>
<span>${formatMoney(tx.amount || 0)}</span>
</div>
</div>
`;
      list.appendChild(card);
    });
  });
}

function updateTerritories() {
  const list = document.getElementById("territory-list") || document.getElementById("territories-list");
  if (!list) return;
  list.innerHTML = "";
  const term = (territorySearch || "").trim().toLowerCase();
  let rows = (territories || []).slice();
  rows = rows.filter(t => {
    const isOwned = t.gangId === gangData.id;
    const isUnclaimed = !t.gangId;
    const isContested = !!t.contested;
    if (territoryFilter === "owned" && !isOwned) return false;
    if (territoryFilter === "unclaimed" && !isUnclaimed) return false;
    if (territoryFilter === "contested" && !isContested) return false;
    return true;
  });
  if (term) {
    rows = rows.filter(t => {
      const blob = [t.name, t.label, t.gangName, t.type].map(v => (v || "").toString().toLowerCase()).join(" ");
      return blob.includes(term);
    });
  }
  if (rows.length === 0) {
    list.innerHTML = '<div class="empty-state"><i class="fas fa-map"></i><p>No territories</p></div>';
    return;
  }
  rows.forEach(t => {
    const ownedClass = t.gangId === gangData.id ? "online" : (t.contested ? "offline" : "");
    const ownerText = t.gangId === gangData.id ? "Owned" : (t.gangId ? "Occupied" : "Unclaimed");
    const incomeValue = (typeof t.income === "number" ? t.income : (typeof t.income_rate === "number" ? t.income_rate : 0));
    const incomeText = `${formatMoney(incomeValue)}/hr`;

        const frontBadge = (t.hasFront || t.frontType) 
      ? `<i class="fas fa-store" style="color: #2ecc71; margin-left: 8px;" title="Has Business Front"></i>` 
      : '';

    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.setAttribute("data-name", t.name);
    card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">
${escapeHtml(t.label || t.name)}
<span class="ac-status ${ownedClass}">${ownerText}${t.contested ? ' • Contested' : ''}</span>
</div>
<div class="player-details-tablet">
<span>Type: ${escapeHtml(t.type || "-")}</span>
<span>Income: ${incomeText}</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="view" data-name="${escapeHtml(t.name)}">
<i class="fas fa-map-marker-alt"></i><span>View</span>
</button>
</div>
`;
    list.appendChild(card);
  });
  const ownedStat = document.getElementById("owned-territories") || document.getElementById("stat-territories");
  if (ownedStat) {
    const owned = (territories || []).filter(t => t.gangId === gangData.id).length;
    ownedStat.textContent = owned;
  }
}

function updateBusinesses() {
  const list = document.getElementById("business-list") || document.getElementById("businesses-list");
  if (!list) return;
  list.innerHTML = "";
  (businesses || []).forEach(b => {
    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.setAttribute("data-id", b.id);
    card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml((b.type || "Business").replace(/_/g, " "))}</div>
<div class="player-details-tablet">
<span>Level: ${b.level || 1}</span>
<span>Income/hr: ${formatMoney(b.income || 0)}</span>
<span>Stored: ${formatMoney(b.income_stored || 0)}</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="collect" data-id="${b.id}"><i class="fas fa-dollar-sign"></i><span>Collect</span></button>
<button class="quick-action-btn" data-action="upgrade" data-upgrade="level" data-id="${b.id}"><i class="fas fa-level-up-alt"></i><span>Upgrade</span></button>
<button class="quick-action-btn" data-action="view" data-id="${b.id}"><i class="fas fa-map-marker-alt"></i><span>View</span></button>
</div>
`;
    list.appendChild(card);
  });
}

function updateFronts() {
  const list = document.getElementById("business-list");
  if (!list) return;
  list.innerHTML = "";

  if (!fronts || fronts.length === 0) {
    list.innerHTML = '<div class="empty-state"><i class="fas fa-store"></i><p>No fronts assigned. Capture territories with business fronts to unlock them!</p></div>';
    return;
  }

  fronts.forEach(f => {
    const pool = f.pool || {};
    const ratePct = Math.floor((f.rate || 0) * 100);
    const feePct = Math.floor((f.fee || 0) * 100);
    const cap = f.cap || 0;
    
    const territoryBadge = f.territoryName 
      ? `<span style="color: #667eea; font-size: 12px;"><i class="fas fa-map-marker-alt"></i> ${escapeHtml(f.territoryName)}</span>`
      : '';

    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.setAttribute("data-id", f.id);
    card.innerHTML = `
      <div class="player-info-tablet">
        <div class="player-name-tablet">
          ${escapeHtml(f.label || f.ref || ("Front #" + String(f.id)))}
          <span class="ac-status ${f.heat > 0 ? "online" : "offline"}">Heat: ${Number(f.heat || 0)}</span>
        </div>
        <div class="player-details-tablet">
          ${territoryBadge}
          <span>Dirty Pool: ${formatMoney(pool.dirty_value || 0)}</span>
          <span>Today: $${formatMoney(pool.processed_today || 0)} /$$ {formatMoney(cap)}</span>
          <span>Rate: ${ratePct}%</span>
          <span>Fee: ${feePct}%</span>
        </div>
      </div>
      <div class="player-ping-tablet">
        <button class="quick-action-btn" data-action="front-deposit" data-id="${f.id}">
          <i class="fas fa-money-bill-wave"></i><span>Deposit Dirty</span>
        </button>
        <button class="quick-action-btn" data-action="front-status" data-id="${f.id}">
          <i class="fas fa-info-circle"></i><span>Status</span>
        </button>
        <button class="quick-action-btn" data-action="front-catalog" data-id="${f.id}">
          <i class="fas fa-boxes"></i><span>Catalog</span>
        </button>
      </div>
    `;
    list.appendChild(card);
  });
}

/* Vehicles helpers */
function safeInsertBefore(parent, node, ref) {
  if (!parent || !node) return;
  if (ref && parent.contains(ref) && ref.parentElement === parent) {
    parent.insertBefore(node, ref);
  } else {
    parent.appendChild(node);
  }
}

function promptFrontDeposit(frontId) {
  showAdminModal(
    `<i class="fas fa-money-bill-wave"></i> Deposit Dirty`,
    `
      <div class="form-group">
        <label>Amount ($)</label>
        <input id="front-deposit-amount" type="number" class="tablet-input" min="1" placeholder="e.g., 25000" />
      </div>
    `,
    `
      <button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Cancel</button>
      <button class="modal-btn modal-btn-confirm" onclick="(function(){
        const amt = parseInt(document.getElementById('front-deposit-amount')?.value, 10) || 0;
        if (amt <= 0) { showNotification('Error','Enter a valid amount','error'); return; }
        postNUI('fronts_deposit', { frontId: ${frontId}, amount: amt });
        closeAdminModal();
        setTimeout(() => postNUI('refreshFronts'), 300);
      })()">Deposit</button>
    `
  );
}

function openFrontCatalog(frontId) {
  postNUI("fronts_get_status", { frontId });
  setTimeout(() => {
    // Catalog editor after status arrives
    const handler = (event) => {
      const { action, type, data } = event.data || {};
      if (action === "update" && type === "frontStatus" && data && data.front && data.front.id === frontId) {
        window.removeEventListener("message", handler);
        const f = data.front;
        const list = Array.isArray(data.illegal) ? data.illegal : [];
        const rows = list.map((r, i) => `
          <div class="player-card-tablet" data-i="${i}">
            <div class="player-info-tablet">
              <div class="player-name-tablet">${escapeHtml(r.item)}</div>
              <div class="player-details-tablet">
                <span>Price: <input type="number" class="tablet-input" style="width:110px" value="${Number(r.price||0)}" data-k="price" data-i="${i}"/></span>
                <span>Stock: <input type="number" class="tablet-input" style="width:90px" value="${Number(r.stock||0)}" data-k="stock" data-i="${i}"/></span>
                <span>Max: <input type="number" class="tablet-input" style="width:90px" value="${Number(r.max_stock||0)}" data-k="max_stock" data-i="${i}"/></span>
                <span>Visible: <input type="checkbox" ${r.visible ? "checked":""} data-k="visible" data-i="${i}"/></span>
              </div>
            </div>
          </div>
        `).join("");

        showAdminModal(
          `<i class="fas fa-boxes"></i> Catalog: ${escapeHtml(f.label || f.ref)}`,
          `
            <div class="players-list-tablet" id="front-catalog-list">
              ${rows || '<div class="empty-state"><i class="fas fa-box"></i><p>No items</p></div>'}
            </div>
            <div class="form-card mt">
              <h3><i class="fas fa-plus-circle"></i> Add Item</h3>
              <div class="grid four">
                <input id="fc-item" class="tablet-input" placeholder="item name"/>
                <input id="fc-price" class="tablet-input" type="number" placeholder="price"/>
                <input id="fc-stock" class="tablet-input" type="number" placeholder="stock"/>
                <input id="fc-max" class="tablet-input" type="number" placeholder="max stock"/>
              </div>
              <div class="form-group" style="margin-top:10px">
                <label><input id="fc-visible" type="checkbox" class="tablet-checkbox"/> Visible</label>
              </div>
            </div>
          `,
          `
            <button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Close</button>
            <button class="modal-btn modal-btn-confirm" onclick="(function(){
              const rows = ${JSON.stringify(list)};
              // apply edits
              document.querySelectorAll('#front-catalog-list [data-k]').forEach(inp => {
                const i = parseInt(inp.getAttribute('data-i'),10);
                const k = inp.getAttribute('data-k');
                if (k === 'visible') rows[i][k] = !!inp.checked;
                else rows[i][k] = parseInt(inp.value,10) || 0;
              });
              // add new if provided
              const ni = (document.getElementById('fc-item')?.value || '').trim();
              if (ni) {
                rows.push({
                  item: ni,
                  price: parseInt(document.getElementById('fc-price')?.value,10) || 0,
                  stock: parseInt(document.getElementById('fc-stock')?.value,10) || 0,
                  max_stock: parseInt(document.getElementById('fc-max')?.value,10) || 0,
                  visible: !!document.getElementById('fc-visible')?.checked
                });
              }
              postNUI('fronts_set_catalog', { frontId: ${frontId}, list: rows });
              closeAdminModal();
              setTimeout(() => postNUI('fronts_get_status', { frontId: ${frontId} }), 300);
            })()">Save</button>
          `
        );
      }
    };
    window.addEventListener("message", handler);
  }, 50);
}
/* ===========================
Updater: Vehicles (fixed)
=========================== */
function updateVehicles() {
  const list = document.getElementById("vehicle-list") || document.getElementById("vehicles-list");
  if (!list) return;

  // Handle both array and enriched payload formats
  let vehiclesArr = [];
  let garage = null;
  let catalog = [];
  let canSetGarage = false;
  let canPurchase = false;

  if (Array.isArray(vehicles)) {
    vehiclesArr = vehicles;
  } else if (vehicles && typeof vehicles === "object") {
    vehiclesArr = vehicles.vehicles || vehicles.list || [];
    garage = vehicles.garage || null;
    catalog = vehicles.catalog || [];
    canSetGarage = !!(vehicles.canSetGarage || vehicles.canManageGarage);
    canPurchase = !!vehicles.canPurchase;
    if (typeof vehicles.recallPrice === "number") window.RecallPrice = vehicles.recallPrice;
  }

  const RECALL_PRICE = (typeof window.RecallPrice === "number" ? window.RecallPrice : 50000);

  // Update or create garage card
  const vehiclesScreen = document.getElementById("vehicles-screen");
  if (vehiclesScreen) {
    let garageCard = document.getElementById("gang-garage-card");
    if (!garageCard) {
      garageCard = document.createElement("div");
      garageCard.id = "gang-garage-card";
      garageCard.className = "form-card";
      const appContent = vehiclesScreen.querySelector(".app-content");
      if (appContent && list.parentElement === appContent) {
        appContent.insertBefore(garageCard, list);
      }
    }

    const garageText = garage
      ? `Set at: (${Number(garage.x || 0).toFixed(1)}, ${Number(garage.y || 0).toFixed(1)})`
      : "No garage set for your gang";
    garageCard.innerHTML = `
<h3><i class="fas fa-warehouse"></i> Gang Garage</h3>
<div class="player-details-section">
<div class="player-detail-row">
<div class="player-detail-label">Location</div>
<div class="player-detail-value">${garageText}</div>
</div>
</div>
<div class="quick-actions-bar">
<div class="quick-action-btn" data-action="garage-waypoint">
<i class="fas fa-map-marker-alt"></i><span>Waypoint</span>
</div>
${canSetGarage ? `
<div class="quick-action-btn" data-action="garage-set-here">
<i class="fas fa-map-pin"></i><span>Set Garage Here</span>
</div>` : ``}
</div>
`;

    // Update or create buy card
    let buyCard = document.getElementById("gang-vehicle-buy-card");
    if (!buyCard) {
      buyCard = document.createElement("div");
      buyCard.className = "form-card mt";
      buyCard.id = "gang-vehicle-buy-card";
      const appContent = vehiclesScreen.querySelector(".app-content");
      if (appContent && list.parentElement === appContent) {
        appContent.insertBefore(buyCard, list);
      }
    }

    if (canPurchase && catalog && catalog.length > 0) {
      let optionsHtml = '';
      catalog.forEach(c => {
        const priceText = (typeof c.price === "number") ? formatMoney(c.price) : (c.price ?? "");
        const label = c.label || c.model;
        optionsHtml += `
<div class="player-card-tablet" data-model="${escapeHtml(c.model)}">
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(label)}</div>
<div class="player-details-tablet">
<span>Price: ${escapeHtml(priceText)}</span>
<span>Model: ${escapeHtml(String(c.model))}</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="buy-vehicle" data-model="${escapeHtml(String(c.model))}">
<i class="fas fa-shopping-cart"></i><span>Buy</span>
</button>
</div>
</div>`;
      });
      buyCard.innerHTML = `
<h3><i class="fas fa-shopping-cart"></i> Buy Gang Vehicle</h3>
<div class="players-list-tablet" id="buy-list">${optionsHtml}</div>
`;
    } else if (canPurchase) {
      buyCard.innerHTML = `
<h3><i class="fas fa-shopping-cart"></i> Buy Gang Vehicle</h3>
<div class="empty-state"><i class="fas fa-car"></i><p>No catalog configured</p></div>
`;
    } else {
      buyCard.innerHTML = `
<h3><i class="fas fa-shopping-cart"></i> Buy Gang Vehicle</h3>
<div class="empty-state">
<i class="fas fa-lock"></i>
<p>Only managers can purchase vehicles for the gang.</p>
</div>
`;
    }
  }

  // Update vehicles list
  list.innerHTML = "";
  vehiclesArr.forEach(v => {
    const isStored = Number(v.stored) === 1 || v.stored === true;
    const label = v.label || v.model || "Vehicle";
    const plate = v.plate || "";
    const recallPriceStr = formatMoney(RECALL_PRICE);

    const actions = isStored
      ? `<button class="quick-action-btn" data-action="spawn" data-plate="${escapeHtml(plate)}"><i class="fas fa-car"></i><span>Spawn</span></button>`
      : `
<button class="quick-action-btn" data-action="track" data-plate="${escapeHtml(plate)}"><i class="fas fa-location-arrow"></i><span>Track</span></button>
${canSetGarage ? `<button class="quick-action-btn" data-action="recall" data-plate="${escapeHtml(plate)}"><i class="fas fa-undo"></i><span>Recall (${escapeHtml(recallPriceStr)})</span></button>` : ``}
`;

    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.setAttribute("data-plate", plate);
    card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(label)} (${escapeHtml(plate)})</div>

<div class="player-details-tablet">
<span>Status: ${isStored ? "Stored" : "Out"}</span>
</div>
</div>
<div class="player-ping-tablet">
${actions}
<button class="quick-action-btn" data-action="view" data-plate="${escapeHtml(plate)}">
<i class="fas fa-info-circle"></i><span>Details</span>
</button>
</div>
`;
    list.appendChild(card);
  });

  // Bind actions once
  if (!vehiclesBindingsInit) {
    vehiclesBindingsInit = true;
    const vehiclesScreen = document.getElementById("vehicles-screen");
    if (vehiclesScreen) {
      vehiclesScreen.addEventListener("click", (e) => {
        const btn = e.target.closest(".quick-action-btn, [data-action]");
        if (!btn) return;
        const act = btn.getAttribute("data-action");
        if (!act) return;

        if (act === "garage-waypoint") {
          postNUI("garageWaypoint");
          return;
        }
        if (act === "garage-set-here") {
          postNUI("setGangGarage");
          return;
        }
        if (act === "buy-vehicle") {
          const model = btn.getAttribute("data-model");
          if (model) postNUI("buyGangVehicle", { model });
          return;
        }

        const plate = btn.getAttribute("data-plate");
        if (!plate) return;

        if (act === "spawn") postNUI("spawnVehicle", { plate });
        else if (act === "store") postNUI("storeVehicle", { plate });
        else if (act === "track") postNUI("trackVehicle", { plate });
        else if (act === "view") postNUI("viewVehicle", { plate });
        else if (act === "recall") postNUI("recallVehicle", { plate });
      });
    }
  }
}

function updateDrugs() {
  const labsList = document.getElementById("lab-list") || document.getElementById("labs-list");
  const fieldsList = document.getElementById("field-list") || document.getElementById("fields-list");
  if (labsList) {
    labsList.innerHTML = "";
    (drugLabs || []).forEach(l => {
      const card = document.createElement("div");
      card.className = "player-card-tablet";
      card.setAttribute("data-id", l.id);
      card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml((l.drugType || "Lab").replace(/_/g, " "))}</div>
<div class="player-details-tablet">
<span>Level: ${l.level || 1}</span>
<span>Capacity: ${l.capacity || 0}</span>
<span>Security: ${l.security || 1}</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="process" data-id="${l.id}"><i class="fas fa-flask"></i><span>Process</span></button>
<button class="quick-action-btn" data-action="upgrade" data-type="capacity" data-id="${l.id}"><i class="fas fa-plus-circle"></i><span>Capacity</span></button>
<button class="quick-action-btn" data-action="upgrade" data-type="security" data-id="${l.id}"><i class="fas fa-shield-alt"></i><span>Security</span></button>
<button class="quick-action-btn" data-action="upgrade" data-type="level" data-id="${l.id}"><i class="fas fa-level-up-alt"></i><span>Level</span></button>
<button class="quick-action-btn" data-action="view" data-id="${l.id}"><i class="fas fa-map-marker-alt"></i><span>View</span></button>
</div>
`;
      labsList.appendChild(card);
    });
  }
  if (fieldsList) {
    fieldsList.innerHTML = "";
    (drugFields || []).forEach(f => {
      const card = document.createElement("div");
      card.className = "player-card-tablet";
      card.setAttribute("data-id", f.id);
      card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml((f.resourceType || "Field").replace(/_/g, " "))}</div>
<div class="player-details-tablet">
<span>Growth: ${f.growthStage || 0}/10</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="harvest" data-id="${f.id}"><i class="fas fa-cut"></i><span>Harvest</span></button>
<button class="quick-action-btn" data-action="view" data-id="${f.id}"><i class="fas fa-map-marker-alt"></i><span>View</span></button>
</div>
`;
      fieldsList.appendChild(card);
    });
  }
}

function updateWars() {
  const list = document.getElementById("war-list") || document.getElementById("wars-list");
  if (!list) return;
  list.innerHTML = "";
  const warsArray = Array.isArray(activeWars) ? activeWars : Object.values(activeWars || {});
  const badge = document.getElementById("wars-badge");
  if (badge) {
    if (warsArray.length > 0) {
      badge.textContent = warsArray.length;
      badge.classList.remove("hidden");
    } else {
      badge.classList.add("hidden");
    }
  }
  if (warsArray.length === 0) {
    list.innerHTML = '<div class="empty-state"><i class="fas fa-peace"></i><p>No active wars</p></div>';
    return;
  }
  warsArray.forEach(w => {
    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.setAttribute("data-id", w.id);
    card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(w.attackerName)} vs ${escapeHtml(w.defenderName)}</div>
<div class="player-details-tablet">
<span>Territory: ${escapeHtml(w.territoryName)}</span>
<span>Score: ${w.attackerScore} - ${w.defenderScore}</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="view" data-id="${w.id}"><i class="fas fa-map-marker-alt"></i><span>View</span></button>
<button class="quick-action-btn" data-action="surrender" data-id="${w.id}"><i class="fas fa-flag"></i><span>Surrender</span></button>
</div>
`;
    list.appendChild(card);
  });
}

function updateHeists() {
  const list = document.getElementById("heist-list") || document.getElementById("heists-list");
  if (!list) return;
  list.innerHTML = "";
  const arr = Array.isArray(activeHeists) ? activeHeists : Object.values(activeHeists || {});
  if (arr.length === 0) {
    list.innerHTML = '<div class="empty-state"><i class="fas fa-skull-crossbones"></i><p>No active heists</p></div>';
    return;
  }
  arr.forEach(h => {
    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.setAttribute("data-id", h.id);
    card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(String(h.heistType || "Heist").replace(/_/g, " "))}</div>
<div class="player-details-tablet"><span>Stage: ${h.currentStage}</span></div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="start-mission" data-id="${h.id}"><i class="fas fa-play"></i><span>Start</span></button>
<button class="quick-action-btn" data-action="join" data-id="${h.id}"><i class="fas fa-user-plus"></i><span>Join</span></button>
<button class="quick-action-btn" data-action="cancel" data-id="${h.id}"><i class="fas fa-times"></i><span>Cancel</span></button>
</div>
`;
    list.appendChild(card);
  });
}

function updateSettings() {
  const n = document.getElementById("set-name") || document.getElementById("setting-name");
  const t = document.getElementById("set-tag") || document.getElementById("setting-tag");
  const c = document.getElementById("set-color") || document.getElementById("setting-color");
  const l = document.getElementById("set-logo");
  const m = document.getElementById("set-max");
  if (n) n.value = gangData.name || "";
  if (t) t.value = gangData.tag || "";
  if (c) c.value = gangData.color || "#ff3e3e";
  if (l) l.value = gangData.logo || "";
  if (m) m.value = gangData.max_members || 25;
}

/* ===========================
Updater: Stashes
=========================== */
function updateStashes() {
  loadGangStash();
  loadSharedStashes();
}

function loadGangStash() {
  postNUI("getGangStash");
}

function loadSharedStashes() {
  postNUI("getSharedStashes");
}

function renderGangStash(stash) {
  currentGangStash = stash || null;

  const slotsEl = document.getElementById('mainStashSlots');
  const weightEl = document.getElementById('mainStashWeight');
  const statusEl = document.getElementById('mainStashStatus');
  const teleportBtn = document.getElementById('teleportMainStashBtn');
  const locEl = document.getElementById('mainStashLoc'); // add

  if (slotsEl) slotsEl.textContent = stash?.slots || '-';
  if (weightEl) weightEl.textContent = stash?.weight ? (stash.weight / 1000).toFixed(0) : '-';

  if (statusEl) {
    if (stash?.hasLocation) {
      statusEl.textContent = 'Active';
      statusEl.className = 'ac-status online';
    } else {
      statusEl.textContent = 'Not Set';
      statusEl.className = 'ac-status offline';
    }
  }

  // NEW: show location text
  if (locEl) {
    if (stash?.location && typeof stash.location.x === 'number' && typeof stash.location.y === 'number') {
      locEl.textContent = `(${stash.location.x.toFixed(2)}, ${stash.location.y.toFixed(2)})`;
    } else {
      locEl.textContent = '-';
    }
  }

  if (teleportBtn) {
    if (stash?.hasLocation) {
      teleportBtn.style.opacity = '1';
      teleportBtn.style.pointerEvents = 'auto';
    } else {
      teleportBtn.style.opacity = '0.5';
      teleportBtn.style.pointerEvents = 'none';
    }
  }
}

function renderSharedStashes(stashes) {
  currentSharedStashes = stashes || [];
  const listContainer = document.getElementById('sharedStashList');
  if (!listContainer) return;

  listContainer.innerHTML = '';

  if (!stashes || stashes.length === 0) {
    listContainer.innerHTML = '<div class="empty-state"><i class="fas fa-box"></i><p>No shared stashes created yet</p></div>';
    return;
  }

  stashes.forEach(stash => {
    const card = createSharedStashElement(stash);
    listContainer.appendChild(card);
  });
}

function createSharedStashElement(stash) {
  // Get minimum rank from accessRanks
  let minRank = 1;
  if (stash.accessRanks && typeof stash.accessRanks === 'object') {
    const ranks = Object.keys(stash.accessRanks).map(Number);
    if (ranks.length > 0) {
      minRank = Math.min(...ranks);
    }
  }

  const rankName = getRankName(minRank);

  const card = document.createElement('div');
  card.className = 'player-card-tablet';
  card.setAttribute('data-stash-id', stash.id);
  card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(stash.name)}</div>
<div class="player-details-tablet">
<span>Slots: ${stash.slots || 50}</span>
<span>Weight: ${(stash.weight / 1000).toFixed(0)}kg</span>
<span>Min Rank: ${rankName}</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" data-action="teleport-shared" data-stash-id="${stash.id}">
<i class="fas fa-map-marker-alt"></i><span>Teleport</span>
</button>
<button class="quick-action-btn" data-action="delete-shared" data-stash-id="${stash.id}">
<i class="fas fa-trash"></i><span>Delete</span>
</button>
</div>
`;
  return card;
}

function getRankName(rank) {
  const ranks = {
    1: 'Rank 1',
    2: 'Rank 2',
    3: 'Rank 3',
    4: 'Rank 4',
    5: 'Rank 5',
    6: 'Rank 6'
  };
  return ranks[rank] || 'Unknown';
}

function setMainStashLocation() {
  postNUI('setGangStashLocation');
}

function openMainStash() {
  if (!currentGangStash || !currentGangStash.hasLocation) {
    showNotification('Error', 'Main stash location not set', 'error');
    return;
  }
  postNUI('openMainStash');
}

function teleportToMainStash() {
  if (!currentGangStash || !currentGangStash.hasLocation) {
    showNotification('Error', 'Main stash location not set', 'error');
    return;
  }
  postNUI('teleportToStash', { type: 'main' });
}

function promptCreateSharedStash() {
  showAdminModal(
    '<i class="fas fa-plus-circle"></i> Create Shared Stash',
    `
<div class="form-group">
<label>Stash Name</label>
<input type="text" id="createStashName" class="tablet-input" placeholder="e.g., Weapons Cache" maxlength="50" />
</div>
<div class="form-group">
<label>Minimum Rank Required</label>
<select id="createStashMinRank" class="tablet-input">
<option value="1">Rank 1 and above</option>
<option value="2">Rank 2 and above</option>
<option value="3">Rank 3 and above</option>
<option value="4">Rank 4 and above</option>
<option value="5">Rank 5 and above</option>
<option value="6">Rank 6 only</option>
</select>
</div>
<div style="background: rgba(102, 126, 234, 0.1); border-left: 3px solid #667eea; padding: 10px; border-radius: 5px; margin-top: 15px;">
<p style="color: rgba(255,255,255,0.8); margin: 0; font-size: 13px;">
<i class="fas fa-info-circle"></i> The stash will be created at your current location
</p>
</div>
`,
    `
<button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Cancel</button>
<button class="modal-btn modal-btn-confirm" onclick="confirmCreateSharedStash()"><i class="fas fa-check"></i> Create</button>
`
  );
}

function confirmCreateSharedStash() {
  const name = document.getElementById('createStashName')?.value.trim();
  const minRank = document.getElementById('createStashMinRank')?.value;

  if (!name) {
    showNotification('Error', 'Please enter a stash name', 'error');
    return;
  }

  postNUI('createSharedStash', { name, minRank: parseInt(minRank) || 1 });
  closeAdminModal();
}

function deleteSharedStash(stashId, stashName) {
  if (!confirm(`Are you sure you want to delete "${stashName}"?\nThis cannot be undone!`)) {
    return;
  }
  postNUI('deleteSharedStash', { stashId });
}

/* ===========================
Admin Helpers
=========================== */
function switchAdminTab(tab) {
  currentAdminTab = tab;
  const tabs = document.querySelectorAll("#admin-screen .category-tab-tablet");
  tabs.forEach(t => t.classList.remove("active"));
  const activeBtn = Array.from(tabs).find(t => (t.getAttribute("data-adtab") || "").toLowerCase() === tab);
  if (activeBtn) activeBtn.classList.add("active");

  document.querySelectorAll('#admin-screen .admin-tab-content, #admin-content > div[id^="admin-tab-"]').forEach(c => c.classList.add("hidden"));
  const id1 = `admin-${tab}-tab`;
  const id2 = `admin-tab-${tab}`;
  const panel = document.getElementById(id1) || document.getElementById(id2);
  if (panel) panel.classList.remove("hidden");
}

function filterAdminGangs() {
  const term = (document.getElementById("ad-gangs-search")?.value || "").toLowerCase();
  document.querySelectorAll("#admin-gangs-list .player-card-tablet").forEach(card => {
    const text = card.textContent.toLowerCase();
    card.style.display = text.includes(term) ? "flex" : "none";
  });
}
function filterAdminPlayers() {
  const term = (document.getElementById("ad-players-search")?.value || "").toLowerCase();
  document.querySelectorAll("#admin-players-list .player-card-tablet").forEach(card => {
    const text = card.textContent.toLowerCase();
    card.style.display = text.includes(term) ? "flex" : "none";
  });
}
function filterAdminTerritories() {
  const term = (document.getElementById("ad-territories-search")?.value || "").toLowerCase();
  document.querySelectorAll("#admin-territories-list .player-card-tablet, #admin-territories-list .teleport-card").forEach(card => {
    const text = card.textContent.toLowerCase();
    card.style.display = text.includes(term) ? "flex" : "none";
  });
}

function refreshAdminData() {
  showNotification("Info", "Refreshing admin data...", "info");
  postNUI("admin_refresh_data");
}

function showAdminModal(title, body, footer) {
  const root = document.getElementById("modal-root");
  if (!root) return;
  root.innerHTML = `
<div class="modal-overlay" id="admin-modal-overlay">
<div class="modal-container">
<div class="modal-header">
<div class="modal-title">${title}</div>
<button class="modal-close" onclick="closeAdminModal()"><i class="fas fa-times"></i></button>
</div>
<div class="modal-body" id="admin-modal-body">${body}</div>
<div class="modal-footer" id="admin-modal-footer">${footer}</div>
</div>
</div>
`;
}
function closeAdminModal() {
  const root = document.getElementById("modal-root");
  if (root) root.innerHTML = "";
}

function showCreateGangModal() {
  showAdminModal(
    '<i class="fas fa-plus-circle"></i> Create Gang',
    `
<div class="form-group"><label>Gang Name</label><input type="text" id="admin-gang-name" class="tablet-input" placeholder="Enter gang name..."></div>
<div class="form-group"><label>Gang Tag</label><input type="text" id="admin-gang-tag" class="tablet-input" placeholder="3-5 characters..."></div>
<div class="form-group"><label>Gang Color</label><input type="color" id="admin-gang-color" class="tablet-input" value="#ff3e3e"></div>
<div class="form-group"><label>Max Members</label><input type="number" id="admin-gang-max" class="tablet-input" value="25" min="5" max="50"></div>
`,
    `
<button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Cancel</button>
<button class="modal-btn modal-btn-confirm" onclick="createGang()"><i class="fas fa-plus"></i> Create</button>
`
  );
}
function createGang() {
  const name = document.getElementById("admin-gang-name").value;
  const tag = document.getElementById("admin-gang-tag").value;
  const color = document.getElementById("admin-gang-color").value;
  const maxMembers = parseInt(document.getElementById("admin-gang-max").value, 10);
  if (!name || !tag) return showNotification("Error", "Please fill in all fields", "error");
  postNUI("admin_create_gang", { name, tag, color, maxMembers });
  closeAdminModal();
}
function editGang(gangId) {
  const gang = adminGangs.find(g => g.id === gangId);
  if (!gang) return;

  const mainSlots = gang.main_stash_slots ?? 50;
  const mainWeightKg = Math.round((gang.main_stash_weight ?? 1000000) / 1000);
  const sharedSlots = gang.shared_stash_slots ?? 50;
  const sharedWeightKg = Math.round((gang.shared_stash_weight ?? 1000000) / 1000);
  const sharedLimit = gang.shared_stash_limit_count ?? 0;

  showAdminModal(
    '<i class="fas fa-edit"></i> Edit Gang',
    `
      <div class="form-group"><label>Gang Name</label><input type="text" id="admin-gang-name" class="tablet-input" value="${escapeHtml(gang.name)}"></div>
      <div class="form-group"><label>Gang Tag</label><input type="text" id="admin-gang-tag" class="tablet-input" value="${escapeHtml(gang.tag)}"></div>
      <div class="form-group"><label>Gang Color</label><input type="color" id="admin-gang-color" class="tablet-input" value="${escapeHtml(gang.color)}"></div>
      <div class="form-group"><label>Max Members</label><input type="number" id="admin-gang-max" class="tablet-input" value="${gang.max_members || gang.maxMembers || 25}" min="5" max="50"></div>

      <div class="form-card mt">
        <h3><i class="fas fa-box"></i> Stash Caps</h3>
        <div class="grid four">
          <div>
            <label>Main Stash Slots</label>
            <input type="number" id="admin-main-slots" class="tablet-input" min="10" max="200" value="${mainSlots}">
          </div>
          <div>
            <label>Main Stash Weight (kg)</label>
            <input type="number" id="admin-main-weight" class="tablet-input" min="10" max="1000" value="${mainWeightKg}">
          </div>
          <div>
            <label>Shared Stash Slots</label>
            <input type="number" id="admin-shared-slots" class="tablet-input" min="10" max="200" value="${sharedSlots}">
          </div>
          <div>
            <label>Shared Stash Weight (kg)</label>
            <input type="number" id="admin-shared-weight" class="tablet-input" min="10" max="1000" value="${sharedWeightKg}">
          </div>
        </div>
        <div class="grid one mt">
          <div>
            <label>Max Shared Stashes (0 = unlimited)</label>
            <input type="number" id="admin-shared-limit" class="tablet-input" min="0" max="50" value="${sharedLimit}">
          </div>
        </div>
      </div>
    `,
    `
      <button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Cancel</button>
      <button class="modal-btn modal-btn-confirm" onclick="updateGang(${gangId})"><i class="fas fa-save"></i> Save</button>
    `
  );
}

function updateGang(gangId) {
  const name = document.getElementById("admin-gang-name").value;
  const tag = document.getElementById("admin-gang-tag").value;
  const color = document.getElementById("admin-gang-color").value;
  const maxMembers = parseInt(document.getElementById("admin-gang-max").value, 10);

  const mainStashSlots = parseInt(document.getElementById("admin-main-slots")?.value, 10) || 50;
  const mainStashWeight = (parseInt(document.getElementById("admin-main-weight")?.value, 10) || 100) * 1000; // kg -> g
  const sharedStashSlots = parseInt(document.getElementById("admin-shared-slots")?.value, 10) || 50;
  const sharedStashWeight = (parseInt(document.getElementById("admin-shared-weight")?.value, 10) || 100) * 1000; // kg -> g
  const sharedStashLimit = parseInt(document.getElementById("admin-shared-limit")?.value, 10) || 0;

  postNUI("admin_update_gang", {
    gangId,
    name,
    tag,
    color,
    maxMembers,
    mainStashSlots,
    mainStashWeight,
    sharedStashSlots,
    sharedStashWeight,
    sharedStashLimit
  });
  closeAdminModal();
}

function deleteGang(gangId) {
  if (!confirm("Are you sure you want to delete this gang? This cannot be undone!")) return;
  postNUI("admin_delete_gang", { gangId });
}
function viewGangMembers(gangId) {
  postNUI("admin_get_gang_members", { gangId });
  setTimeout(() => {
    let html = '<div class="players-list-tablet" style="max-height: 400px; overflow-y: auto;">';
    html += '<p style="color: var(--text-secondary); text-align: center; padding: 20px;">Loading members...</p>';
    html += "</div>";
    showAdminModal('<i class="fas fa-users"></i> Gang Members', html, '<button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Close</button>');
  }, 100);
}
function removeGangMember(gangId, citizenId) {
  if (!confirm("Remove this member from the gang?")) return;
  postNUI("admin_remove_member", { gangId, citizenId });
}
function removePlayerFromGang(citizenId, gangId) {
  if (!confirm("Remove this player from their gang?")) return;
  postNUI("admin_remove_member", { gangId, citizenId });
}
function setTerritoryOwner(territoryName) {
  let gangsHTML = '<div class="form-group"><label>Select Gang</label><select id="territory-gang-select" class="tablet-select">';
  gangsHTML += '<option value="">Unclaimed</option>';
  (adminGangs || []).forEach(g => { gangsHTML += `<option value="${g.id}">${escapeHtml(g.name)} [${escapeHtml(g.tag)}]</option>`; });
  gangsHTML += "</select></div>";
  showAdminModal(
    '<i class="fas fa-map-marker-alt"></i> Set Territory Owner',
    gangsHTML,
    `
<button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Cancel</button>
<button class="modal-btn modal-btn-confirm" onclick="saveTerritoryOwner('${territoryName}')"><i class="fas fa-save"></i> Save</button>
`
  );
}
function saveTerritoryOwner(territoryName) {
  const gangId = document.getElementById("territory-gang-select").value;
  postNUI("admin_set_territory_owner", { territoryName, gangId: gangId || null });
  closeAdminModal();
}
function showAssignPlayerModal(citizenId) {
  let gangsHTML = '<div class="form-group"><label>Select Gang</label><select id="assign-gang-select" class="tablet-select">';
  gangsHTML += '<option value="" disabled selected>Select a gang...</option>';
  (adminGangs || []).forEach(g => { gangsHTML += `<option value="${g.id}">${escapeHtml(g.name)} [${escapeHtml(g.tag)}]</option>`; });
  gangsHTML += '</select></div>';
  const ranksHTML = `
<div class="form-group">
<label>Rank (1-6)</label>
<input type="number" id="assign-rank-input" class="tablet-input" min="1" max="6" value="1">
</div>
`;
  showAdminModal(
    '<i class="fas fa-user-plus"></i> Assign Player to Gang',
    `
<div class="form-group"><label>Citizen ID</label><input type="text" class="tablet-input" value="${escapeHtml(citizenId)}" disabled></div>
${gangsHTML}
${ranksHTML}
`,
    `
<button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Cancel</button>
<button class="modal-btn modal-btn-confirm" onclick="saveAssignPlayer('${escapeHtml(citizenId)}')"><i class="fas fa-save"></i> Assign</button>
`
  );
}
function saveAssignPlayer(citizenId) {
  const gangIdRaw = document.getElementById('assign-gang-select')?.value;
  const rankRaw = document.getElementById('assign-rank-input')?.value;
  const gangId = parseInt(gangIdRaw, 10);
  const rank = Math.max(1, Math.min(6, parseInt(rankRaw || '1', 10)));
  if (!gangId) return showNotification('Error', 'Select a valid gang', 'error');
  postNUI('admin_add_member', { gangId, citizenId, rank });
  closeAdminModal();
  setTimeout(() => refreshAdminData(), 300);
}

function updateAdminGangs(gangs) {
  adminGangs = gangs || [];
  const list = document.getElementById("admin-gangs-list");
  if (!list) return;
  list.innerHTML = "";
  adminGangs.forEach(g => {
    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.innerHTML = `
<div class="player-avatar-tablet" style="background: linear-gradient(135deg, ${g.color}, ${g.color}80);"><i class="fas fa-crown"></i></div>
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(g.name)} [${escapeHtml(g.tag)}]</div>
<div class="player-details-tablet">
<span>ID: ${g.id}</span>
<span>Members: ${g.member_count || g.memberCount || 0}</span>
<span>Bank: ${formatMoney(g.bank || 0)}</span>
</div>
</div>
<div style="display:flex; gap:6px;">
<button class="quick-action-btn" style="min-width:auto; padding:8px;" onclick="editGang(${g.id})"><i class="fas fa-edit"></i></button>
<button class="quick-action-btn" style="min-width:auto; padding:8px;" onclick="viewGangMembers(${g.id})"><i class="fas fa-users"></i></button>
<button class="quick-action-btn" style="min-width:auto; padding:8px;" onclick="deleteGang(${g.id})"><i class="fas fa-trash"></i></button>
</div>
`;
    list.appendChild(card);
  });
}

function updateAdminPlayers(players) {
  adminPlayers = players || [];
  const playersList = document.getElementById('admin-players-list');
  if (!playersList) return;
  playersList.innerHTML = '';
  adminPlayers.forEach(p => {
    const gid = (p.gang_id !== undefined ? p.gang_id : p.gangId);
    const gname = (p.gang_name !== undefined ? p.gang_name : p.gangName);
    const inGang = !!gid;
    const gangLabel = gname ? `Gang: ${escapeHtml(gname)}` : (gid ? `Gang #${gid}` : 'No Gang');
    const actions = inGang
      ? `
<button class="quick-action-btn" style="min-width:auto;padding:8px;" title="Promote" onclick="postNUI('admin_promote_member', { gangId: ${gid}, citizenId: '${escapeHtml(p.citizenid)}' })"><i class="fas fa-arrow-up"></i></button>
<button class="quick-action-btn" style="min-width:auto;padding:8px;" title="Demote" onclick="postNUI('admin_demote_member', { gangId: ${gid}, citizenId: '${escapeHtml(p.citizenid)}' })"><i class="fas fa-arrow-down"></i></button>
<button class="quick-action-btn" style="min-width:auto;padding:8px;" title="Remove from gang" onclick="removePlayerFromGang('${escapeHtml(p.citizenid)}', ${gid})"><i class="fas fa-user-slash"></i></button>
`
      : `<button class="quick-action-btn" style="min-width:auto;padding:8px;" title="Assign to gang" onclick="showAssignPlayerModal('${escapeHtml(p.citizenid)}')"><i class="fas fa-user-plus"></i></button>`;
    const card = document.createElement('div');
    card.className = 'player-card-tablet';
    card.innerHTML = `
<div class="player-avatar-tablet"><i class="fas fa-user"></i></div>
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(p.name || p.playerName || p.citizenid)}</div>
<div class="player-details-tablet">
<span>ID: ${escapeHtml(p.citizenid)}</span>
<span>${gangLabel}</span>
</div>
</div>
<div style="display:flex; gap:6px;">${actions}</div>
`;
    playersList.appendChild(card);
  });
}

function updateAdminTerritories(territoriesData) {
  adminTerritories = territoriesData || [];
  const list = document.getElementById("admin-territories-list");
  if (!list) return;
  list.innerHTML = "";
  adminTerritories.forEach(t => {
    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(t.label || t.name)}
<span class="ac-status ${t.gangId ? "online" : "offline"}">${escapeHtml(t.gangName || "Unclaimed")}</span>
</div>
<div class="player-details-tablet">
<span>Type: ${escapeHtml(t.type || "-")}</span>
<span>Income: ${formatMoney(t.income || 0)}/hr</span>
</div>
</div>
<div class="player-ping-tablet">
<button class="quick-action-btn" style="min-width:auto; padding:8px;" onclick="setTerritoryOwner('${escapeHtml(t.name)}')"><i class="fas fa-user-shield"></i><span>Set Owner</span></button>
</div>
`;
    list.appendChild(card);
  });
}

function updateAdminLogs(logs) {
  adminLogs = logs || [];
  const list = document.getElementById("admin-logs-list");
  if (!list) return;
  list.innerHTML = "";
  adminLogs.forEach(log => {
    const map = {
      gang_created: { icon: "fa-plus-circle", color: "#2ecc71" },
      gang_deleted: { icon: "fa-trash", color: "#e74c3c" },
      member_joined: { icon: "fa-user-plus", color: "#3498db" },
      member_left: { icon: "fa-user-minus", color: "#f39c12" },
      territory_captured: { icon: "fa-flag", color: "#9b59b6" },
      war_started: { icon: "fa-shield-alt", color: "#e74c3c" }
    };
    const meta = map[log.type] || { icon: "fa-info-circle", color: "#95a5a6" };
    const card = document.createElement("div");
    card.className = "player-card-tablet";
    card.style.marginBottom = "8px";
    card.innerHTML = `
<div class="player-avatar-tablet" style="background:${meta.color}20;"><i class="fas ${meta.icon}" style="color:${meta.color};"></i></div>
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(log.message || log.details || log.type)}</div>
<div class="player-details-tablet">
<span>${escapeHtml(formatDate(log.timestamp || log.ts))}</span>
${log.gang_name ? `<span>${escapeHtml(log.gang_name)}</span>` : ""}
</div>
</div>
`;
    list.appendChild(card);
  });
}

/* ===========================
Side drawers fill
=========================== */
function fillBusinessDrawer(d) {
  document.getElementById("bd-type").textContent = (d.type || "").replace(/_/g, " ").toUpperCase();
  document.getElementById("bd-level").textContent = d.level ?? 1;
  document.getElementById("bd-income").textContent = formatMoney(d.income || 0);
  document.getElementById("bd-stored").textContent = formatMoney(d.income_stored || 0);
  document.getElementById("bd-employees").textContent = d.employees ?? 0;
  document.getElementById("bd-capacity").textContent = d.capacity ?? 0;
  document.getElementById("bd-security").textContent = d.security ?? 1;
  const inv = document.getElementById("bd-emp-list");
  if (inv) inv.innerHTML = '<div class="empty-state"><i class="fas fa-users"></i><p>No employees data</p></div>';
  openDrawer("business-drawer");
}
function fillVehicleDrawer(d) {
  document.getElementById("vd-plate").textContent = d.plate || "-";
  document.getElementById("vd-model").textContent = d.model || d.label || "Unknown";
  document.getElementById("vd-status").textContent = d.stored ? "Stored" : "Out";
  document.getElementById("vd-lastseen").textContent = d.last_seen || "-";
  openDrawer("vehicle-drawer");
}
function fillLabDrawer(d) {
  document.getElementById("ld-type").textContent = (d.drugType || d.type || "").toUpperCase();
  document.getElementById("ld-level").textContent = d.level ?? 1;
  document.getElementById("ld-capacity").textContent = d.capacity ?? 0;
  document.getElementById("ld-security").textContent = d.security ?? 1;
  const inv = document.getElementById("ld-inventory");
  if (inv) {
    inv.innerHTML = "";
    if (d.inventory && typeof d.inventory === "object") {
      Object.entries(d.inventory).forEach(([item, amount]) => {
        const row = document.createElement("div");
        row.className = "player-card-tablet";
        row.innerHTML = `<div class="player-info-tablet"><div class="player-name-tablet">${escapeHtml(item)}</div><div class="player-details-tablet"><span>Amount: ${amount}</span></div></div>`;
        inv.appendChild(row);
      });
    } else {
      inv.innerHTML = '<div class="empty-state"><i class="fas fa-box"></i><p>No inventory</p></div>';
    }
  }
  openDrawer("lab-drawer");
}
function fillHeistDrawer(d) {
  document.getElementById("hd-type").textContent = (d.heist_type || d.heistType || "Heist").replace(/_/g, " ");
  document.getElementById("hd-stage").textContent = d.current_stage || d.currentStage || 1;
  document.getElementById("hd-start").textContent = d.start_time || formatDate(Date.now());
  openDrawer("heist-drawer");
}
function fillWarDrawer(d) {
  document.getElementById("wd-attacker").textContent = d.attacker_name || d.attackerName || "-";
  document.getElementById("wd-defender").textContent = d.defender_name || d.defenderName || "-";
  document.getElementById("wd-territory").textContent = d.territory_name || d.territoryName || "-";
  const a = d.attacker_score || d.attackerScore || 0;
  const b = d.defender_score || d.defenderScore || 0;
  document.getElementById("wd-score").textContent = `${a} - ${b}`;
  openDrawer("war-drawer");
}
function openDrawer(id) {
  const dr = document.getElementById(id);
  if (dr) dr.classList.remove("hidden");
}
function closeDrawer(id) {
  const dr = document.getElementById(id);
  if (dr) dr.classList.add("hidden");
}

/* ===========================
Bindings
=========================== */
function initUIBindings() {
  if (bindingsInit) return;
  bindingsInit = true;

  const closeBtn = document.getElementById("btn-close");
  if (closeBtn) closeBtn.addEventListener("click", () => requestCloseUI());

  // App grid openers
  document.addEventListener("click", (e) => {
    const appIcon = e.target.closest(".app-icon");
    if (!appIcon) return;
    const openId = appIcon.getAttribute("data-open");
    if (!openId) return;
    const name = openId.replace("-screen", "");
    openScreen(name);

    if (name === "vehicles") {
      postNUI("refreshVehicles"); // request enriched payload
    } else if (name === "admin") {
      switchAdminTab("gangs");
      refreshAdminData();
    } else if (name === "stash") {
      updateStashes();
    } else if (name === "businesses") {
    postNUI("refreshFronts");
    }    
  });

  // Generic backs
  document.addEventListener("click", (e) => {
    if (e.target.closest("[data-back]")) openScreen("home");
    if (e.target.closest("[data-close-drawer]")) {
      const dr = e.target.closest(".drawer");
      if (dr) dr.classList.add("hidden");
    }
  });

  // Admin tabs
  document.querySelectorAll("#admin-screen .category-tab-tablet").forEach((btn) => {
    btn.addEventListener("click", () => {
      const tab = (btn.getAttribute("data-adtab") || "").toLowerCase();
      if (tab) switchAdminTab(tab);
    });
  });

  // Refresh buttons
  document.getElementById("btn-refresh-admin")?.addEventListener("click", refreshAdminData);
  document.getElementById("btn-refresh-gang")?.addEventListener("click", () => postNUI("refreshUI"));
  document.getElementById("btn-refresh-territories")?.addEventListener("click", () => postNUI("refreshTerritories"));
  document.getElementById("btn-refresh-businesses")?.addEventListener("click", () => postNUI("refreshBusinesses"));
  document.getElementById("btn-refresh-vehicles")?.addEventListener("click", () => postNUI("refreshVehicles"));
  document.getElementById("btn-refresh-drugs")?.addEventListener("click", () => postNUI("refreshDrugs"));
  document.getElementById("btn-refresh-heists")?.addEventListener("click", () => postNUI("refreshHeists"));
  document.getElementById("btn-refresh-wars")?.addEventListener("click", () => postNUI("refreshWars"));
  document.getElementById("btn-refresh-bank")?.addEventListener("click", () => postNUI("refreshBank"));

  // Admin quick actions
  document.querySelector('#admin-screen [data-action="admin-create-gang"]')?.addEventListener("click", () => {
    const name = document.getElementById("ad-create-name")?.value.trim();
    const tag = document.getElementById("ad-create-tag")?.value.trim();
    const color = document.getElementById("ad-create-color")?.value || "#ff3e3e";
    const maxMembers = parseInt(document.getElementById("ad-create-max")?.value, 10) || 25;

    const mainStashSlots = parseInt(document.getElementById("ad-create-main-slots")?.value, 10) || 50;
    const mainStashWeight = (parseInt(document.getElementById("ad-create-main-weight")?.value, 10) || 100) * 1000; // kg -> g
    const sharedStashSlots = parseInt(document.getElementById("ad-create-shared-slots")?.value, 10) || 50;
    const sharedStashWeight = (parseInt(document.getElementById("ad-create-shared-weight")?.value, 10) || 100) * 1000; // kg -> g
    const sharedStashLimit = parseInt(document.getElementById("ad-create-sharedmax")?.value, 10) || 0;

    if (!name || !tag) return showNotification("Error", "Please fill in Name and Tag", "error");
    showNotification("Info", "Submitting creation request...", "info");

    postNUI("admin_create_gang", {
      name, tag, color, maxMembers,
      mainStashSlots, mainStashWeight,
      sharedStashSlots, sharedStashWeight,
      sharedStashLimit
    });

    setTimeout(() => refreshAdminData(), 500);
  });

  // Admin filters
  document.getElementById("ad-gangs-search")?.addEventListener("input", filterAdminGangs);
  document.getElementById("ad-players-search")?.addEventListener("input", filterAdminPlayers);
  document.getElementById("ad-territories-search")?.addEventListener("input", filterAdminTerritories);

  // Set territory owner (inline)
  const setOwnerBtn = document.querySelector('#admin-tab-territories [data-action="admin-set-owner"]');
  if (setOwnerBtn) {
    setOwnerBtn.addEventListener("click", () => {
      const territory = document.getElementById("ad-set-territory")?.value.trim();
      const gidRaw = document.getElementById("ad-set-gangid")?.value;
      const gangId = gidRaw === "" ? null : parseInt(gidRaw, 10);
      if (!territory) return showNotification("Error", "Enter a territory name", "error");
      postNUI("admin_set_territory_owner", { territoryName: territory, gangId });
      setTimeout(() => refreshAdminData(), 300);
    });
  }

  // Members invite
  document.querySelector('#members-screen [data-action="invite"]')?.addEventListener("click", () => {
    const id = parseInt(document.getElementById("invite-server-id")?.value, 10);
    if (!id || id <= 0) return showNotification("Error", "Enter a valid server ID", "error");
    postNUI("invitePlayer", { targetId: id });
  });

  // Bank actions
  const bankContent = document.getElementById("bank-content");
  if (bankContent) {
    bankContent.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-bank]");
      if (!btn) return;
      const action = btn.getAttribute("data-bank");
      if (action === "deposit") {
        const amt = parseInt(document.getElementById("bank-deposit-amt")?.value, 10) || 0;
        if (amt <= 0) return showNotification("Error", "Enter deposit amount", "error");
        postNUI("depositMoney", { amount: amt });
      } else if (action === "withdraw") {
        const amt = parseInt(document.getElementById("bank-withdraw-amt")?.value, 10) || 0;
        if (amt <= 0) return showNotification("Error", "Enter withdraw amount", "error");

        const FEE_RATE = (window.Config?.Economy?.transactionFee) ?? 0;
        const fee = Math.floor(amt * FEE_RATE + 0.5); // round to nearest integer
        if (fee > 0) {
          showNotification("Info", `Fee: ${currencySymbol}${fee}. Total deducted: ${currencySymbol}${amt + fee}`, "info");
        }
        postNUI("withdrawMoney", { amount: amt });
      } else if (action === "transfer") {
        const gid = parseInt(document.getElementById("bank-transfer-gid")?.value, 10) || 0;
        const amt = parseInt(document.getElementById("bank-transfer-amt")?.value, 10) || 0;
        const reason = document.getElementById("bank-transfer-reason")?.value || "";
        if (gid <= 0 || amt <= 0) return showNotification("Error", "Enter target gang id and amount", "error");

        const FEE_RATE = (window.Config?.Economy?.transactionFee) ?? 0;
        const fee = Math.floor(amt * FEE_RATE + 0.5);
        if (fee > 0) {
          showNotification("Info", `Fee: ${currencySymbol}${fee}. Total deducted: ${currencySymbol}${amt + fee}`, "info");
        }
        postNUI("transferMoney", { targetGangId: gid, amount: amt, reason });
      }
    });
  }

  // Territories click: view/open drawer
  const terrContainers = [
    document.getElementById("territory-list"),
    document.getElementById("territories-list"),
    document.getElementById("territories-screen")
  ].filter(Boolean);
  terrContainers.forEach((container) => {
    container.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-action]");
      if (!btn) return;
      const act = btn.getAttribute("data-action");
      if (act !== "view") return;
      let name = btn.getAttribute("data-name");
      if (!name) {
        const card = btn.closest(".player-card-tablet");
        if (card) name = card.getAttribute("data-name");
      }
      if (!name) return showNotification("Error", "No territory selected", "error");
      postNUI("viewTerritory", { territoryName: name });
    });
  });

  // Drawer actions for territories (waypoint/upgrade)
  document.addEventListener("click", (e) => {
    const btn = e.target.closest("#territory-drawer [data-action], #territory-drawer [data-upgrade]");
    if (!btn) return;
    const act = btn.getAttribute("data-action");
    if (act === "view" || act === "waypoint") {
      if (!lastTerritoryDetails || !lastTerritoryDetails.coords) {
        showNotification("Error", "No coordinates for this territory", "error");
        return;
      }
      postNUI("territoryWaypoint", { x: lastTerritoryDetails.coords.x, y: lastTerritoryDetails.coords.y });
      return;
    }
    const up = btn.getAttribute("data-upgrade");
    if (up) {
      if (!lastTerritoryDetails || !lastTerritoryDetails.name) {
        showNotification("Error", "No territory selected", "error");
        return;
      }
      const upgradeType = (up || "").toLowerCase();
      postNUI("upgradeTerritory", {
        name: lastTerritoryDetails.name,
        territoryName: lastTerritoryDetails.name,
        upgradeType
      });
    }
  });

  // Territories filters and search
  document.getElementById("territory-filters")?.addEventListener("click", (e) => {
    const chip = e.target.closest(".filter-chip");
    if (!chip) return;
    document.querySelectorAll("#territory-filters .filter-chip").forEach((c) => c.classList.remove("active"));
    chip.classList.add("active");
    territoryFilter = (chip.getAttribute("data-filter") || "all").toLowerCase();
    updateTerritories();
  });
  document.getElementById("territory-search")?.addEventListener("input", (e) => {
    territorySearch = e.target.value || "";
    updateTerritories();
  });

  // Stash Management (add this inside initUIBindings function, before the closing brace)
  document.getElementById('setMainStashBtn')?.addEventListener('click', setMainStashLocation);
  document.getElementById('openMainStashBtn')?.addEventListener('click', openMainStash);
  document.getElementById('teleportMainStashBtn')?.addEventListener('click', teleportToMainStash);
  document.getElementById('createSharedStashBtn')?.addEventListener('click', promptCreateSharedStash);
  document.getElementById('btn-refresh-stash')?.addEventListener('click', updateStashes);

  // Shared stash actions
  document.getElementById('sharedStashList')?.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-action]');
    if (!btn) return;
    const action = btn.getAttribute('data-action');
    const stashId = btn.getAttribute('data-stash-id');
    if (!stashId) return;

    if (action === 'open-shared') {
      postNUI('openSharedStash', { stashId: parseInt(stashId) });
    } else if (action === 'teleport-shared') {
      postNUI('teleportToStash', { stashId: parseInt(stashId), type: 'shared' });
    } else if (action === 'delete-shared') {
      const card = btn.closest('.player-card-tablet');
      const name = card?.querySelector('.player-name-tablet')?.textContent || 'this stash';
      deleteSharedStash(parseInt(stashId), name);
    }
  });

  // Shared stash search
  document.getElementById('shared-stash-search')?.addEventListener('input', (e) => {
    const term = e.target.value.toLowerCase();
    document.querySelectorAll('#sharedStashList .player-card-tablet').forEach(card => {
      const text = card.textContent.toLowerCase();
      card.style.display = text.includes(term) ? '' : 'none';
    });
  });


  // Businesses
  // Fronts (repurpose Businesses tab)
  document.getElementById("btn-refresh-businesses")?.addEventListener("click", () => postNUI("refreshFronts"));

document.addEventListener("click", (e) => {
  const appIcon = e.target.closest(".app-icon");
  if (!appIcon) return;
  const openId = appIcon.getAttribute("data-open");
  if (!openId) return;
  const name = openId.replace("-screen", "");
  if (name === "businesses") postNUI("refreshFronts");
});
  document.getElementById("businesses-screen")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-action]");
    if (!btn) return;
    const act = btn.getAttribute("data-action");
    const id = parseInt(btn.getAttribute("data-id"), 10);
    if (!id) return;

    if (act === "front-deposit") {
      promptFrontDeposit(id);
    } else if (act === "front-status") {
      postNUI("fronts_get_status", { frontId: id });
    } else if (act === "front-catalog") {
      openFrontCatalog(id);
    }
  });

  // Vehicles: Register button
  document.querySelector('#vehicles-screen [data-action="register-vehicle"]')?.addEventListener("click", () => postNUI("registerVehicle"));

  // Drugs creation
  document.querySelector('#drugs-screen [data-action="create-field"]')?.addEventListener("click", () => {
    const rt = document.getElementById("create-field-type")?.value.trim();
    const terr = document.getElementById("create-field-terr")?.value.trim();
    if (!rt || !terr) return showNotification("Error", "Enter resourceType and territoryName", "error");
    postNUI("createField", { resourceType: rt, territoryName: terr });
  });
  document.querySelector('#drugs-screen [data-action="create-lab"]')?.addEventListener("click", () => {
    const dt = document.getElementById("create-lab-type")?.value.trim();
    const terr = document.getElementById("create-lab-terr")?.value.trim();
    if (!dt || !terr) return showNotification("Error", "Enter drugType and territoryName", "error");
    postNUI("createLab", { drugType: dt, territoryName: terr });
  });
  document.getElementById("lab-list")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-action]");
    if (!btn) return;
    const act = btn.getAttribute("data-action");
    const id = btn.getAttribute("data-id");
    if (!id) return;
    if (act === "process") postNUI("processDrugs", { labId: id });
    else if (act === "upgrade") {
      const up = btn.getAttribute("data-type") || "level";
      postNUI("upgradeLab", { labId: id, upgradeType: up });
    } else if (act === "view") postNUI("viewLab", { labId: id });
  });
  document.getElementById("field-list")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-action]");
    if (!btn) return;
    const act = btn.getAttribute("data-action");
    const id = btn.getAttribute("data-id");
    if (!id) return;
    if (act === "harvest") postNUI("harvestField", { fieldId: id });
    else if (act === "view") postNUI("viewField", { fieldId: id });
  });

  // Heists
  document.querySelector('#heists-screen [data-action="start-heist"]')?.addEventListener("click", () => {
    const ht = document.getElementById("heist-type")?.value.trim();
    if (!ht) return showNotification("Error", "Enter heistType", "error");
    postNUI("startHeist", { heistType: ht });
  });
  document.getElementById("heist-list")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-action]");
    if (!btn) return;
    const act = btn.getAttribute("data-action");
    const id = btn.getAttribute("data-id");
    if (!id) return;
    if (act === "start-mission") postNUI("startHeistMission", { heistId: id });
    else if (act === "join") postNUI("joinHeist", { heistId: id });
    else if (act === "cancel") postNUI("cancelHeist", { heistId: id });
  });

  // Wars
  document.querySelector('#wars-screen [data-action="declare-war"]')?.addEventListener("click", () => {
    const target = parseInt(document.getElementById("war-target-gid")?.value, 10) || 0;
    const terr = document.getElementById("war-territory-name")?.value.trim() || "";
    if (!target || !terr) return showNotification("Error", "Enter targetGangId and territoryName", "error");
    postNUI("declareWar", { targetGangId: target, territoryName: terr });
  });
  document.getElementById("war-list")?.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-action]");
    if (!btn) return;
    const act = btn.getAttribute("data-action");
    const id = btn.getAttribute("data-id");
    if (!id) return;
    if (act === "surrender") postNUI("surrenderWar", { warId: id });
    else if (act === "view") postNUI("viewWar", { warId: id });
  });

  // Settings
  document.querySelector('#settings-screen [data-action="save-name"]')?.addEventListener("click", () => {
    const val = document.getElementById("set-name")?.value.trim();
    if (!val) return showNotification("Error", "Please enter a name", "error");
    postNUI("changeGangName", { name: val });
  });
  document.querySelector('#settings-screen [data-action="save-tag"]')?.addEventListener("click", () => {
    const val = document.getElementById("set-tag")?.value.trim();
    if (!val) return showNotification("Error", "Please enter a tag", "error");
    postNUI("changeGangTag", { tag: val });
  });
  document.querySelector('#settings-screen [data-action="save-color"]')?.addEventListener("click", () => {
    const val = document.getElementById("set-color")?.value || "#ff3e3e";
    postNUI("changeGangColor", { color: val });
  });
  document.querySelector('#settings-screen [data-action="save-logo"]')?.addEventListener("click", () => {
    const val = document.getElementById("set-logo")?.value.trim() || "";
    postNUI("changeGangLogo", { logo: val });
  });
  document.querySelector('#settings-screen [data-action="save-max"]')?.addEventListener("click", () => {
    const val = parseInt(document.getElementById("set-max")?.value, 10) || 25;
    postNUI("setMaxMembers", { amount: val });
  });
  document.querySelector('#settings-screen [data-action="leave-gang"]')?.addEventListener("click", () => {
    if (!confirm("Are you sure you want to leave the gang?")) return;
    postNUI("leaveGang");
  });
  document.querySelector('#settings-screen [data-action="disband-gang"]')?.addEventListener("click", () => {
    if (!confirm("Are you sure you want to disband the gang? This cannot be undone!")) return;
    postNUI("disbandGang");
  });
}

/* ===========================
NUI message handler
=========================== */
window.addEventListener("message", (event) => {
  const data = event.data;
  const action = data.action || data.type;

  switch (action) {
    case "openGangMenu": {
      if (data.config && (data.config.CurrencySymbol || data.config.currencySymbol)) {
        currencySymbol = data.config.CurrencySymbol || data.config.currencySymbol || currencySymbol || "£";
      }
      if (data.playerData) {
        playerData = data.playerData; updatePlayerInfo();
      }
      if (data.gangData) {
        gangData = data.gangData; updateGangInfo();
      }
      if (data.members) {
        members = data.members; updateMembers();
      }
      if (data.territories) {
        territories = data.territories; updateTerritories();
      }
      if (data.transactions) {
        transactions = data.transactions; updateTransactions();
      }
      if (data.businesses) {
        businesses = data.businesses; updateBusinesses();
      }
      if (data.gangVehicles) {
        // May be an array; enriched data will arrive via refreshVehicles
        vehicles = data.gangVehicles; updateVehicles();
      }
      if (data.drugFields) {
        drugFields = data.drugFields;
      }
      if (data.config) {
        window.Config = data.config;
      }
      if (data.drugLabs) {
        drugLabs = data.drugLabs; updateDrugs();
      }
      if (data.activeWars) {
        activeWars = data.activeWars; updateWars();
      }
      if (data.gangStash) {
        renderGangStash(data.gangStash);
      }
      if (data.sharedStashes) {
        renderSharedStashes(data.sharedStashes);
      }
      if (data.activeHeists) {
        activeHeists = data.activeHeists; updateHeists();
      }
      updateStats();
      updateSettings();
      if (data.startTab === "admin") currentScreen = "admin";

      openUI();
      hideLoading();

      // Pull enriched vehicles payload (garage, catalog, caps)
      setTimeout(() => postNUI("refreshVehicles"), 50);
      setTimeout(() => postNUI("refreshFronts"), 60);
      break;
    }

    case "openUI": {
      if (data.config && (data.config.CurrencySymbol || data.config.currencySymbol)) {
        currencySymbol = data.config.CurrencySymbol || data.config.currencySymbol || currencySymbol || "£";
      }
      openUI();
      openScreen(data.startTab || "home");
      setTimeout(() => {
        initUIBindings();
        if (data.startTab === "admin") {
          switchAdminTab("gangs");
          refreshAdminData();
        }
      }, 50);
      break;
    }

    case "showLoading":
      showLoading(data.message || "Loading...");
      break;

    case "hideLoading":
      hideLoading();
      break;

    case "close":
      applyCloseUI();
      break;

    case "refreshUI": {
      if (data.gang) {
        gangData = data.gang;
        updateGangInfo();
        updateStats();
      }
      if (data.members) {
        members = data.members; updateMembers();
      }
      if (data.territories) {
        territories = data.territories; updateTerritories();
      }
      if (data.transactions) {
        transactions = data.transactions; updateTransactions();
      }
      if (data.businesses) {
        businesses = data.businesses; updateBusinesses();
      }
      if (data.gangVehicles) {
        vehicles = data.gangVehicles; updateVehicles();
      }
      if (data.drugFields) {
        drugFields = data.drugFields;
      }
      if (data.drugLabs) {
        drugLabs = data.drugLabs; updateDrugs();
      }
      if (data.activeWars) {
        activeWars = data.activeWars; updateWars();
      }
      if (data.activeHeists) {
        activeHeists = data.activeHeists; updateHeists();
      }
      break;
    }

    case "update": {
      // Generic update multiplexer; includes enriched vehicles payload
      const { type, data: updateData } = data;

      // Vehicles enriched payload from NUI: { vehicles[], garage, catalog, canSetGarage, canPurchase, recallPrice }
      if (type === "vehicles" && updateData) {
        if (typeof updateData.recallPrice === "number") window.RecallPrice = updateData.recallPrice;
        vehicles = updateData;
        updateVehicles();
        break;
      }

      if (type === "fronts" && updateData) {
  fronts = Array.isArray(updateData) ? updateData : [];
  updateFronts();
  break;
}

// Front status payload -> show modal
if (type === "frontStatus" && updateData && updateData.front) {
  const f = updateData.front || {};
  const p = updateData.pool || {};
  const ls = updateData.illegal || [];

  let items = "";
  if (ls.length === 0) {
    items = '<div class="empty-state"><i class="fas fa-box"></i><p>No illegal items</p></div>';
  } else {
    items = ls.map(r => `
      <div class="player-card-tablet">
        <div class="player-info-tablet">
          <div class="player-name-tablet">${escapeHtml(r.item)}</div>
          <div class="player-details-tablet">
            <span>Price: ${formatMoney(r.price || 0)}</span>
            <span>Stock: ${Number(r.stock || 0)} / ${Number(r.max_stock || 0)}</span>
            <span>${r.visible ? "Visible" : "Hidden"}</span>
          </div>
        </div>
      </div>
    `).join("");
  }

  showAdminModal(
    `<i class="fas fa-info-circle"></i> ${escapeHtml(f.label || f.ref || "Front")}`,
    `
      <div class="player-details-section">
        <div class="player-detail-row"><div class="player-detail-label">Pool</div><div class="player-detail-value">${formatMoney(p.dirty_value || 0)}</div></div>
        <div class="player-detail-row"><div class="player-detail-label">Today</div><div class="player-detail-value">${formatMoney(p.processed_today || 0)} / ${formatMoney(f.cap || 0)}</div></div>
        <div class="player-detail-row"><div class="player-detail-label">Rate</div><div class="player-detail-value">${Math.floor((f.rate || 0)*100)}%</div></div>
        <div class="player-detail-row"><div class="player-detail-label">Fee</div><div class="player-detail-value">${Math.floor((f.fee || 0)*100)}%</div></div>
        <div class="player-detail-row"><div class="player-detail-label">Heat</div><div class="player-detail-value">${Number(f.heat || 0)}</div></div>
      </div>
      <div class="form-card mt">
        <h3><i class="fas fa-boxes"></i> Illegal Catalog</h3>
        <div class="players-list-tablet">${items}</div>
      </div>
    `,
    `<button class="modal-btn modal-btn-cancel" onclick="closeAdminModal()">Close</button>`
  );
  break;
}

      // Admin sections
      const adminHandlers = {
        adminGangs: updateAdminGangs,
        adminPlayers: updateAdminPlayers,
        adminTerritories: updateAdminTerritories,
        adminLogs: updateAdminLogs
      };
      if (updateData && adminHandlers[type]) {
        adminHandlers[type](updateData);
        break;
      }

      // Admin members modal update
      if (type === "adminGangMembers" && updateData) {
        renderGangMembers(updateData);
      }
      break;
    }

    case "updateStashes": {
      if (data.gangStash) renderGangStash(data.gangStash);
      if (data.sharedStashes) renderSharedStashes(data.sharedStashes);
      break;
    }

    case "showTerritoryDetails": {
      const d = data.data || {};
      if (data.config && (data.config.CurrencySymbol || data.config.currencySymbol)) {
        currencySymbol = data.config.CurrencySymbol || data.config.currencySymbol || currencySymbol || "£";
      }

      lastTerritoryDetails = d;

      // Fill drawer fields
      const nameEl = document.getElementById("td-name");
      const ownerEl = document.getElementById("td-owner");
      const statusEl = document.getElementById("td-status");
      const valueEl = document.getElementById("td-value");
      const frontEl = document.getElementById("td-front");

      const displayLabel = (d.label && String(d.label).trim()) || d.name || "-";
      if (nameEl) nameEl.textContent = displayLabel;
      if (ownerEl) ownerEl.textContent = d.gangName || "Unclaimed";
      const statusText = d.contested ? "Contested" : (d.gangId ? "Owned" : "Unclaimed");
      if (statusEl) statusEl.textContent = statusText;

      const incomeValue = (typeof d.income_rate === "number" ? d.income_rate : (typeof d.income === "number" ? d.income : 0));
      if (valueEl) valueEl.textContent = formatMoney(incomeValue || 0);

        if (frontEl) {
    if (d.hasFront || d.frontType) {
      const frontType = d.frontType || d.front_type || "Business Front";
      frontEl.innerHTML = `<i class="fas fa-store" style="color: #2ecc71;"></i> ${escapeHtml(frontType)}`;
    } else {
      frontEl.innerHTML = `<i class="fas fa-times" style="color: #e74c3c;"></i> No Front`;
    }
  }

      const infWrap = document.getElementById("td-influences");
      if (infWrap) {
        infWrap.innerHTML = "";
        const list = Array.isArray(d.influences) ? d.influences : [];
        if (!list.length) {
          infWrap.innerHTML = '<div class="empty-state"><i class="fas fa-users"></i><p>No influence data</p></div>';
        } else {
          list.sort((a, b) => (b.influence || 0) - (a.influence || 0));
          list.forEach((row) => {
            const card = document.createElement("div");
            card.className = "player-card-tablet";
            card.innerHTML = `
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(row.gangName || String(row.gangId || "Gang"))}</div>
<div class="player-details-tablet">
<span>Influence: ${row.influence || 0}</span>
<span style="color:${row.color || "#fff"}">Color</span>
</div>
</div>
`;
            infWrap.appendChild(card);
          });
        }
      }

      // Hide capture/defend by default (server manages permissions)
      const drawer = document.getElementById("territory-drawer");
      if (drawer) {
        drawer.querySelectorAll('[data-action="capture"], [data-action="defend"]').forEach(el => el.classList.add("hidden"));
      }
      openDrawer("territory-drawer");
      break;
    }

    case "notify": {
      const t = data.variant || data.type || "info";
      showNotification(data.title || "Info", data.message || "", t);
      break;
    }

    default:
      break;
  }
});

/* ===========================
Admin: Render gang members modal
=========================== */
function renderGangMembers(data) {
  const body = document.getElementById("admin-modal-body");
  if (!body) return;
  const { gangId: gid, members = [] } = data;
  body.innerHTML = "";

  if (!members.length) {
    body.innerHTML = '<div class="empty-state"><i class="fas fa-users"></i><p>No members</p></div>';
    return;
  }

  const container = document.createElement("div");
  container.className = "players-list-tablet";
  Object.assign(container.style, { maxHeight: "400px", overflowY: "auto" });

  members.forEach((member) => {
    const citizenId = member.citizenId || member.citizenid;
    const displayName = member.name || citizenId;
    const rank = member.rank || 0;
    const row = document.createElement("div");
    row.className = "player-card-tablet";
    row.innerHTML = `
<div class="player-avatar-tablet"><i class="fas fa-user"></i></div>
<div class="player-info-tablet">
<div class="player-name-tablet">${escapeHtml(displayName)}</div>
<div class="player-details-tablet">
<span>ID: ${escapeHtml(citizenId)}</span>
<span>Rank: ${rank}</span>
</div>
</div>
<div>
<button class="quick-action-btn remove-member-btn" style="min-width:auto;padding:8px;" data-gang-id="${gid}" data-citizen-id="${escapeHtml(citizenId)}" aria-label="Remove member">
<i class="fas fa-user-slash"></i>
</button>
</div>
`;
    const btn = row.querySelector(".remove-member-btn");
    btn.addEventListener("click", () => removeGangMember(gid, citizenId));
    container.appendChild(row);
  });

  body.appendChild(container);
}

/* ===========================
Bootstrap bindings
=========================== */
document.addEventListener("DOMContentLoaded", () => {
  initUIBindings();
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && isOpen) {
      requestCloseUI();
    }
  });
});