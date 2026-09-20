const root = document.getElementById('root');
const form = document.getElementById('itemForm');
const fields = Object.fromEntries([...form.querySelectorAll('[id]')].map((element) => [element.id, element]));
const statusNames = ['hunger', 'thirst', 'stress'];
let bootstrap = null;
let selectedName = null;
let selectedMaterials = new Map();
let materialLookup = new Map();
let manualWeight = 100;
let saving = false;
let deleting = false;
let currentCategory = 'food';
let pendingCategory = null;
const statusLabels = { hunger: '空腹', thirst: '喉の渇き', stress: 'ストレス' };

function materialAllowed(material, category) {
  return material?.categories === undefined || material.categories?.[category] === true;
}

function statusAllowed(category, status) {
  const policy = bootstrap?.options?.statusEditing;
  return !policy || policy.mode === 'all' || policy.categories?.[category]?.[status] === true;
}

function categoryCleanup(category) {
  const materials = [...selectedMaterials.keys()].filter((name) => !materialAllowed(materialLookup.get(name), category));
  const statuses = statusNames.filter((status) => !statusAllowed(category, status) && numericField(status) !== 0);
  const alcohol = category !== 'alcohol' && (numericField('alcoholLevel') !== 0 || fields.canOverdose.checked);
  return { materials, statuses, alcohol, needed: materials.length > 0 || statuses.length > 0 || alcohol };
}

function closeCategoryModal() {
  pendingCategory = null;
  document.getElementById('categoryModal').classList.add('hidden');
}

function applyCategory(category) {
  const changes = categoryCleanup(category);
  changes.materials.forEach((name) => selectedMaterials.delete(name));
  changes.statuses.forEach((status) => { fields[status].value = '0'; });
  if (category !== 'alcohol') {
    fields.alcoholLevel.value = '0';
    fields.canOverdose.checked = false;
  } else if (category !== currentCategory) {
    fields.alcoholLevel.value = String(bootstrap?.options?.alcoholBaseLevel ?? 1);
  }
  const sameCategory = category === currentCategory;
  fields.category.value = category;
  currentCategory = category;
  if (!sameCategory) updatePresentationOptions();
  closeCategoryModal();
  renderMaterials();
  toggleConsumableFields();
}

function requestCategory(category) {
  fields.category.value = currentCategory;
  const changes = categoryCleanup(category);
  if (!changes.needed) { applyCategory(category); return; }
  pendingCategory = category;
  document.getElementById('categoryModalTarget').textContent = bootstrap?.options?.categories?.[category] || category;
  const list = document.getElementById('categoryChanges');
  list.replaceChildren();
  const labels = [
    ...changes.materials.map((name) => `素材：${materialLookup.get(name)?.label || name}`),
    ...changes.statuses.map((status) => `${statusLabels[status]}：${numericField(status)} → 0`),
    ...(changes.alcohol ? ['アルコール加算値・過剰摂取設定を解除'] : []),
  ];
  labels.forEach((label) => { const li = document.createElement('li'); li.textContent = label; list.appendChild(li); });
  document.getElementById('categoryModal').classList.remove('hidden');
  document.getElementById('cancelCategoryButton').focus();
}

function setVisible(value) {
  const visible = value === true;
  root.dataset.visible = String(visible);
  root.setAttribute('aria-hidden', String(!visible));
  if (!visible) { closeDeleteModal(); closeCategoryModal(); }
}

function closeDeleteModal() {
  document.getElementById('deleteModal').classList.add('hidden');
}

async function post(endpoint, data = {}) {
  const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
  return response.json();
}

function optionList(select, values, selected) {
  select.innerHTML = '';
  Object.entries(values || {}).forEach(([value, label]) => {
    const option = document.createElement('option');
    option.value = value;
    option.textContent = label;
    option.selected = value === selected;
    select.appendChild(option);
  });
}

function renderExpirationOptions(selectedMinutes) {
  const select = fields.degradeMinutes;
  const options = bootstrap?.options?.expirationOptions || [];
  const defaultMinutes = Number(bootstrap?.options?.defaultExpirationMinutes || 0);
  const selected = Number(selectedMinutes);
  let matched = false;

  select.innerHTML = '';
  options.forEach((configured) => {
    const minutes = Number(configured.minutes);
    const option = document.createElement('option');
    option.value = String(minutes);
    option.textContent = configured.label;
    option.selected = minutes === selected;
    if (option.selected) matched = true;
    select.appendChild(option);
  });

  if (!matched && selectedMinutes !== null && selectedMinutes !== undefined) {
    const legacy = document.createElement('option');
    legacy.value = '';
    legacy.textContent = `現在の設定（${formatNumber(selected)}分・プリセット外）`;
    legacy.selected = true;
    legacy.disabled = true;
    select.prepend(legacy);
  } else if (!matched) {
    select.value = String(defaultMinutes);
  }

  updateExpirationState();
}

function updateExpirationState() {
  fields.decay.disabled = !fields.degradeMinutes.value || numericField('degradeMinutes') <= 0;
}

function updatePresentationFields(selectedProp) {
  const settings = bootstrap?.options?.presentationSettings?.[fields.presentation.value] || {};
  const props = settings.props && Object.keys(settings.props).length
    ? settings.props
    : { none: 'なし' };
  const prop = Object.prototype.hasOwnProperty.call(props, selectedProp)
    ? selectedProp
    : Object.prototype.hasOwnProperty.call(props, settings.defaultProp)
      ? settings.defaultProp
      : Object.keys(props)[0];

  optionList(fields.prop, props, prop);
}

function updatePresentationOptions(selectedPresentation, selectedProp) {
  const allowed = bootstrap?.options?.categoryPresentations?.[fields.category.value] || [];
  const labels = bootstrap?.options?.presentations || {};
  const presentations = {};

  allowed.forEach((name) => {
    if (Object.prototype.hasOwnProperty.call(labels, name)) {
      presentations[name] = labels[name];
    }
  });

  const presentation = Object.prototype.hasOwnProperty.call(presentations, selectedPresentation)
    ? selectedPresentation
    : Object.keys(presentations)[0];

  optionList(fields.presentation, presentations, presentation);
  updatePresentationFields(selectedProp);
}

function setItemName(item) {
  const ownerJob = item?.ownerJob || bootstrap?.access?.ownerJob || '';
  const prefix = `${ownerJob}_`;
  const fullName = item?.name || prefix;
  const suffix = fullName.startsWith(prefix) ? fullName.slice(prefix.length) : fullName;

  fields.ownerJob.value = ownerJob;
  fields.namePrefix.textContent = prefix;
  fields.nameSuffix.maxLength = Math.max(1, 64 - prefix.length);
  fields.nameSuffix.value = suffix;
  fields.nameSuffix.disabled = Boolean(item);
  fields.name.value = fullName;
  validateItemName(false);
}

function validateItemName(showEmptyError = false) {
  const suffix = fields.nameSuffix.value.toLowerCase();
  if (fields.nameSuffix.value !== suffix) fields.nameSuffix.value = suffix;

  const valid = Boolean(selectedName) || /^[a-z0-9]+$/.test(suffix);
  const showError = !valid && (showEmptyError || suffix.length > 0);
  fields.nameError.classList.toggle('hidden', !showError);
  fields.name.value = `${fields.namePrefix.textContent}${suffix}`;
  return valid;
}

function numericField(id) {
  return Number(fields[id]?.value || 0);
}

function formatNumber(value) {
  const rounded = Math.round((Number(value) || 0) * 100) / 100;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}

function resolveItemImage(image) {
  const value = typeof image === 'string' ? image.trim() : '';
  if (!value) return null;
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(value)) return value;

  const base = String(bootstrap?.options?.inventoryImagePath || 'nui://ox_inventory/web/images').replace(/\/+$/, '');
  return `${base}/${encodeURIComponent(value)}`;
}

function clampMaterialCount(value) {
  const max = Number(bootstrap?.options?.maxMaterialCount || 100);
  return Math.min(max, Math.max(1, Math.floor(Number(value) || 1)));
}

function getMetrics() {
  let materialPoints = 0;
  let materialWeight = 0;

  selectedMaterials.forEach((count, name) => {
    const material = materialLookup.get(name);
    if (!material) return;
    materialPoints += Math.max(Number(material.points) || 0, 0) * count;
    materialWeight += Math.max(Number(material.weight) || 0, 0) * count;
  });

  let usedPoints = 0;
  if (fields.type.value === 'usable') {
    const costs = bootstrap?.options?.statusPointCosts || {};
    statusNames.forEach((status) => {
      usedPoints += Math.abs(numericField(status)) * Math.max(Number(costs[status] ?? 1), 0);
    });

    if (fields.category.value === 'alcohol') {
      usedPoints += Math.abs(numericField('alcoholLevel') - Number(bootstrap?.options?.alcoholBaseLevel ?? 1))
        * Math.max(Number(bootstrap?.options?.alcoholPointMultiplier || 0), 0);
    }
  }

  materialPoints = Math.round(materialPoints * 100) / 100;
  materialWeight = Math.round(materialWeight * 100) / 100;
  usedPoints = Math.round(usedPoints * 100) / 100;
  return { materialPoints, materialWeight, usedPoints, remainingPoints: materialPoints - usedPoints };
}

function updateRangeOutputs() {
  statusNames.forEach((status) => {
    fields[`${status}Value`].textContent = formatNumber(numericField(status));
  });
  fields.alcoholLevelValue.textContent = formatNumber(numericField('alcoholLevel'));
  const base = Number(bootstrap?.options?.alcoholBaseLevel ?? 1);
  const multiplier = Math.max(Number(bootstrap?.options?.alcoholPointMultiplier || 0), 0);
  const alcoholPoints = Math.round(Math.abs(numericField('alcoholLevel') - base) * multiplier * 100) / 100;
  fields.alcoholPointHint.textContent = `基準 ${formatNumber(base)} = 0P ／ 基準からの増減1.0につき${formatNumber(multiplier)}P ／ アルコール使用P ${formatNumber(alcoholPoints)}`;
}

function updateSummary() {
  const metrics = getMetrics();
  const overBudget = metrics.remainingPoints < 0;
  const values = {
    materialPoints: formatNumber(metrics.materialPoints),
    usedPoints: formatNumber(metrics.usedPoints),
    remainingPoints: formatNumber(metrics.remainingPoints),
    materialWeight: `${formatNumber(metrics.materialWeight)}g`,
  };

  Object.entries(values).forEach(([id, value]) => {
    document.getElementById(id).textContent = value;
    const inline = document.getElementById(`${id}Inline`);
    if (inline) inline.textContent = value;
  });

  const summary = document.getElementById('pointsSummary');
  summary.classList.toggle('over-budget', overBudget);
  document.querySelector('.material-summary').classList.toggle('over-budget', overBudget);

  const enforceBudget = bootstrap?.options?.enforceMaterialBudget === true;
  fields.pointMessage.textContent = overBudget
    ? `使用Pが素材Pを${formatNumber(Math.abs(metrics.remainingPoints))}P超過しています。`
    : selectedMaterials.size
      ? `あと${formatNumber(metrics.remainingPoints)}P設定できます。`
      : '素材を追加するとステータスへポイントを割り振れます。';
  fields.pointMessage.classList.toggle('error', overBudget);

  const autoWeight = fields.type.value === 'usable' && bootstrap?.options?.autoWeightForUsable !== false;
  fields.weight.readOnly = autoWeight;
  fields.weight.value = autoWeight ? String(Math.floor(metrics.materialWeight)) : String(manualWeight);
  fields.weightLabel.textContent = autoWeight ? '重量（素材から自動計算）' : '重量（g）';
  const expirationValid = fields.degradeMinutes.value !== '';
  const usable = fields.type.value === 'usable';
  const policyInvalid = usable && categoryCleanup(currentCategory).needed;
  fields.categoryWarning.classList.toggle('hidden', !policyInvalid);
  statusNames.forEach((status) => {
    const allowed = statusAllowed(currentCategory, status);
    fields[status].closest('label').classList.toggle('hidden', !allowed);
    fields[status].disabled = !allowed;
  });
  fields.saveButton.disabled = saving || deleting || policyInvalid || !validateItemName(false) || !expirationValid || (enforceBudget && overBudget);
  updateRangeOutputs();
}

function toggleConsumableFields() {
  const usable = fields.type.value === 'usable';
  fields.consumableFields.classList.toggle('hidden', !usable);
  fields.recipeFields.classList.toggle('hidden', !usable);
  fields.alcoholFields.classList.toggle('hidden', !usable || fields.category.value !== 'alcohol');
  updateSummary();
}

function materialSort(left, right) {
  const leftSelected = selectedMaterials.has(left.name);
  const rightSelected = selectedMaterials.has(right.name);
  if (leftSelected !== rightSelected) return leftSelected ? -1 : 1;

  switch (fields.materialSort.value) {
    case 'points':
      return Number(right.points) - Number(left.points) || left.label.localeCompare(right.label, 'ja');
    case 'weight':
      return Number(left.weight) - Number(right.weight) || left.label.localeCompare(right.label, 'ja');
    case 'name':
      return left.label.localeCompare(right.label, 'ja');
    default:
      return left.label.localeCompare(right.label, 'ja');
  }
}

function updateMaterial(name, count) {
  if (count === null) {
    selectedMaterials.delete(name);
  } else {
    selectedMaterials.set(name, clampMaterialCount(count));
  }
  renderMaterials();
  updateSummary();
}

function renderMaterials() {
  const query = fields.materialSearch.value.trim().toLowerCase();
  const selectedOnly = fields.selectedOnly.checked;
  const materials = (bootstrap?.options?.materials || [])
    .filter((material) => {
      if (!materialAllowed(material, currentCategory)) return false;
      if (selectedOnly && !selectedMaterials.has(material.name)) return false;
      return `${material.name} ${material.label}`.toLowerCase().includes(query);
    })
    .sort(materialSort);

  fields.materialGrid.innerHTML = '';
  fields.materialEmpty.classList.toggle('hidden', materials.length > 0);
  fields.materialLimitText.textContent = `最大${bootstrap?.options?.maxMaterials || 10}種類まで選択可能（現在${selectedMaterials.size}種類）`;

  materials.forEach((material) => {
    const selected = selectedMaterials.has(material.name);
    const available = material.available !== false;
    const card = document.createElement('article');
    card.className = `material-card${selected ? ' selected' : ''}${available ? '' : ' unavailable'}`;

    const info = document.createElement('div');
    info.className = 'material-info';
    const title = document.createElement('strong');
    title.textContent = `${material.icon || '📦'} ${material.label}`;
    const meta = document.createElement('small');
    meta.textContent = `P:${formatNumber(material.points)} / W:${formatNumber(material.weight)}g`;
    info.append(title, meta);

    const action = document.createElement('div');
    action.className = 'material-action';
    if (selected) {
      const quantity = document.createElement('span');
      quantity.className = 'material-quantity';
      quantity.textContent = '1個';
      action.appendChild(quantity);
    }

    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = selected ? 'material-toggle remove' : 'material-toggle';
    toggle.textContent = selected ? '削除' : '追加';
    toggle.disabled = !selected && (!available || selectedMaterials.size >= Number(bootstrap?.options?.maxMaterials || 10));
    toggle.title = !available ? 'ox_inventoryに存在しない素材です。選択中の場合は削除できます。' : '';
    toggle.addEventListener('click', () => updateMaterial(material.name, selected ? null : 1));
    action.appendChild(toggle);
    card.append(info, action);
    fields.materialGrid.appendChild(card);
  });
}

function setEditorState(item) {
  const editing = Boolean(item);
  selectedName = item?.name || null;
  closeDeleteModal();
  closeCategoryModal();
  form.reset();
  selectedMaterials = new Map();
  (item?.recipe?.materials || []).forEach((material) => {
    if (material?.name) selectedMaterials.set(material.name, clampMaterialCount(material.count));
  });

  document.getElementById('modeLabel').textContent = editing ? 'EDIT ITEM' : 'NEW ITEM';
  document.getElementById('editorTitle').textContent = editing ? item.label : '新しいアイテム';
  fields.revision.value = editing ? item.revision : '';
  setItemName(item);
  fields.label.value = item?.label || '';
  fields.type.value = item?.type || 'usable';
  manualWeight = Number(item?.weight ?? 100);
  fields.weight.value = String(manualWeight);
  fields.image.value = item?.image || '';
  fields.description.value = item?.description || '';
  fields.stack.checked = item?.stack !== false;
  fields.close.checked = item?.close !== false;
  renderExpirationOptions(item ? item.degradeMinutes : bootstrap?.options?.defaultExpirationMinutes);
  fields.decay.checked = item?.decay === true;
  updateExpirationState();

  const consumable = item?.consumable || {};
  fields.category.value = consumable.category || 'food';
  currentCategory = fields.category.value;
  updatePresentationOptions(consumable.presentation || 'eat', consumable.prop);
  fields.effectPreset.value = consumable.effectPreset || 'none';
  fields.effectDuration.value = consumable.effectDuration || 0;
  fields.alcoholLevel.value = consumable.alcoholLevel ?? (currentCategory === 'alcohol' ? (bootstrap?.options?.alcoholBaseLevel ?? 1) : 0);
  fields.canOverdose.checked = consumable.canOverdose === true;
  fields.hunger.value = consumable.effects?.hunger || 0;
  fields.thirst.value = consumable.effects?.thirst || 0;
  fields.stress.value = consumable.effects?.stress || 0;

  const enabled = item?.enabled !== false;
  const stateBadge = document.getElementById('stateBadge');
  stateBadge.textContent = enabled ? '有効' : '無効';
  stateBadge.className = `badge ${enabled ? 'success' : 'disabled'}`;

  const toggle = fields.toggleButton;
  toggle.classList.toggle('hidden', !editing);
  toggle.textContent = enabled ? '無効化' : '有効化';
  toggle.dataset.enabled = String(!enabled);
  fields.deleteButton.classList.toggle('hidden', !editing);
  fields.deleteButton.disabled = !editing || enabled || deleting;
  fields.deleteButton.textContent = enabled ? '無効化後に削除' : 'アイテムを削除';
  fields.deleteButton.title = enabled ? '削除する前にアイテムを無効化してください。' : '';
  renderMaterials();
  toggleConsumableFields();
  renderItems();
}

function renderItems() {
  const list = document.getElementById('itemList');
  const query = document.getElementById('search').value.trim().toLowerCase();
  const items = (bootstrap?.items || []).filter((item) => `${item.name} ${item.label}`.toLowerCase().includes(query));
  document.getElementById('itemCount').textContent = `${bootstrap?.items?.length || 0}件`;
  list.innerHTML = '';

  if (!items.length) {
    list.innerHTML = '<div class="empty">該当するアイテムはありません</div>';
    return;
  }

  items.forEach((item) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `item-card ${item.enabled ? '' : 'disabled'} ${item.name === selectedName ? 'active' : ''}`;

    const thumbnail = document.createElement('span');
    thumbnail.className = 'item-card-image';
    const placeholder = document.createElement('span');
    placeholder.className = 'item-card-image-placeholder';
    placeholder.textContent = '📦';
    placeholder.setAttribute('aria-hidden', 'true');

    const imageUrl = resolveItemImage(item.image);
    if (imageUrl) {
      const image = document.createElement('img');
      image.src = imageUrl;
      image.alt = `${item.label}のアイテム画像`;
      image.loading = 'lazy';
      image.addEventListener('error', () => {
        image.remove();
        thumbnail.classList.add('missing');
      }, { once: true });
      thumbnail.appendChild(image);
    } else {
      thumbnail.classList.add('missing');
    }
    thumbnail.appendChild(placeholder);

    const copy = document.createElement('span');
    copy.className = 'item-card-copy';
    const title = document.createElement('strong');
    title.textContent = item.label;
    const detail = document.createElement('small');
    detail.textContent = `${item.name} · ${item.type === 'usable' ? '消費' : '通常'}`;
    copy.append(title, detail);
    button.append(thumbnail, copy);
    button.addEventListener('click', () => setEditorState(item));
    list.appendChild(button);
  });
}

function applyBootstrap(data) {
  bootstrap = data;
  materialLookup = new Map((data.options.materials || []).map((material) => [material.name, material]));
  document.getElementById('jobBadge').textContent = `${data.access.ownerJob} / grade ${data.access.grade}${data.access.admin ? ' / ADMIN' : ''}`;
  optionList(fields.type, data.options.itemTypes, 'usable');
  optionList(fields.category, data.options.categories, 'food');
  optionList(fields.effectPreset, data.options.effectPresets, 'none');
  fields.alcoholLevel.max = String(data.options.maxAlcoholLevel || 5);

  const integration = document.getElementById('integration');
  integration.textContent = data.integration.message || '連携状態を取得できません。';
  integration.classList.toggle('error', data.integration.ready !== true);
  setEditorState(data.items.find((item) => item.name === selectedName) || null);
}

function serializeForm() {
  const payload = {
    revision: fields.revision.value ? Number(fields.revision.value) : null,
    name: fields.name.value.trim().toLowerCase(),
    label: fields.label.value.trim(),
    type: fields.type.value,
    weight: numericField('weight'),
    image: fields.image.value.trim(),
    description: fields.description.value.trim(),
    stack: fields.stack.checked,
    close: fields.close.checked,
    degradeMinutes: numericField('degradeMinutes'),
    decay: fields.decay.checked,
    materials: [...selectedMaterials.entries()].map(([name, count]) => ({ name, count })),
  };

  if (payload.type === 'usable') {
    payload.consumable = {
      category: fields.category.value,
      presentation: fields.presentation.value,
      prop: fields.prop.value,
      effectPreset: fields.effectPreset.value,
      effectDuration: numericField('effectDuration'),
      alcoholLevel: numericField('alcoholLevel'),
      canOverdose: fields.canOverdose.checked,
      effects: Object.fromEntries(statusNames.map((status) => [status, numericField(status)])),
    };
  }

  return payload;
}

async function refresh() {
  const result = await post('refresh');
  if (result.success && result.data) applyBootstrap(result.data);
}

window.addEventListener('message', (event) => {
  if (event.data?.action === 'open') {
    try {
      applyBootstrap(event.data.data);
      setVisible(true);
    } catch (error) {
      console.error('[LC_itemcreator] Failed to open NUI:', error);
      setVisible(false);
      post('close');
    }
  } else if (event.data?.action === 'close') {
    setVisible(false);
  }
});

document.getElementById('closeButton').addEventListener('click', () => post('close'));
document.getElementById('refreshButton').addEventListener('click', refresh);
document.getElementById('newButton').addEventListener('click', () => setEditorState(null));
fields.resetButton.addEventListener('click', () => setEditorState(selectedName ? bootstrap.items.find((item) => item.name === selectedName) : null));
document.getElementById('search').addEventListener('input', renderItems);
fields.type.addEventListener('change', toggleConsumableFields);
fields.category.addEventListener('change', () => {
  requestCategory(fields.category.value);
});
fields.reviewCategoryButton.addEventListener('click', () => requestCategory(currentCategory));
document.getElementById('cancelCategoryButton').addEventListener('click', closeCategoryModal);
document.getElementById('confirmCategoryButton').addEventListener('click', () => {
  if (pendingCategory !== null) applyCategory(pendingCategory);
});
fields.presentation.addEventListener('change', () => updatePresentationFields());
fields.degradeMinutes.addEventListener('change', () => {
  updateExpirationState();
  updateSummary();
});
fields.materialSearch.addEventListener('input', renderMaterials);
fields.materialSort.addEventListener('change', renderMaterials);
fields.selectedOnly.addEventListener('change', renderMaterials);
fields.weight.addEventListener('input', () => {
  if (fields.type.value !== 'usable') manualWeight = numericField('weight');
});
statusNames.forEach((status) => fields[status].addEventListener('input', updateSummary));
fields.alcoholLevel.addEventListener('input', updateSummary);
fields.nameSuffix.addEventListener('input', () => {
  validateItemName(true);
  updateSummary();
});

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (fields.saveButton.disabled) return;
  saving = true;
  updateSummary();

  try {
    const itemName = fields.name.value.trim().toLowerCase();
    const result = await post('save', serializeForm());
    if (result?.success && result.data) {
      selectedName = itemName;
      applyBootstrap(result.data);
    }
  } catch (error) {
    console.error('[LC_itemcreator] Failed to save item:', error);
  } finally {
    saving = false;
    updateSummary();
  }
});

fields.toggleButton.addEventListener('click', async (event) => {
  if (!selectedName) return;
  const button = event.currentTarget;
  const name = selectedName;
  const revision = Number(fields.revision.value);
  const enabled = button.dataset.enabled === 'true';
  button.disabled = true;

  try {
    const result = await post('setEnabled', { name, revision, enabled });
    if (result?.success && result.data) applyBootstrap(result.data);
  } catch (error) {
    console.error('[LC_itemcreator] Failed to change item status:', error);
  } finally {
    button.disabled = false;
  }
});

fields.deleteButton.addEventListener('click', () => {
  if (!selectedName || fields.deleteButton.disabled) return;
  document.getElementById('deleteItemName').textContent = selectedName;
  document.getElementById('deleteModal').classList.remove('hidden');
});

document.getElementById('cancelDeleteButton').addEventListener('click', closeDeleteModal);
document.getElementById('confirmDeleteButton').addEventListener('click', async (event) => {
  if (!selectedName || deleting) return;

  const button = event.currentTarget;
  const name = selectedName;
  const revision = Number(fields.revision.value);
  deleting = true;
  button.disabled = true;
  fields.deleteButton.disabled = true;
  updateSummary();

  try {
    const result = await post('delete', { name, revision });
    if (result?.success) {
      selectedName = null;
      closeDeleteModal();
      if (result.data) applyBootstrap(result.data);
      else await refresh();
    }
  } catch (error) {
    console.error('[LC_itemcreator] Failed to delete item:', error);
  } finally {
    deleting = false;
    button.disabled = false;
    fields.deleteButton.disabled = false;
    updateSummary();
  }
});

window.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape' || root.dataset.visible !== 'true') return;
  if (pendingCategory !== null) { closeCategoryModal(); return; }
  if (!document.getElementById('deleteModal').classList.contains('hidden')) {
    closeDeleteModal();
    return;
  }
  post('escape');
});
