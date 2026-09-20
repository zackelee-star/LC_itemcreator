const RESOURCE = 'LC_itemcreator';
const TARGET = 'ox_inventory';
const BEGIN_MARKER = '-- LC_ITEMCREATOR_INTEGRATION_BEGIN';
const END_MARKER = '-- LC_ITEMCREATOR_INTEGRATION_END';

function log(level, message) {
    const color = level === 'ERROR' ? '^1' : level === 'WARN' ? '^3' : '^2';
    console.log(`${color}[LC_itemcreator ${level}]^0 ${message}`);
}

function installFile(sourceRoot, targetRoot, name) {
    const source = path.join(sourceRoot, 'installation', 'ox_inventory', name);
    const target = path.join(targetRoot, name);
    const bundled = fs.readFileSync(source, 'utf8');

    if (fs.existsSync(target)) {
        const installed = fs.readFileSync(target, 'utf8');
        if (installed === bundled) return false;

        throw new Error(`${name} already exists with different contents; update it manually.`);
    }

    fs.writeFileSync(target, bundled, 'utf8');
    log('INFO', `Installed ${name} into ox_inventory.`);
    return true;
}

function installManifest(targetRoot) {
    const manifestPath = path.join(targetRoot, 'fxmanifest.lua');
    const manifest = fs.readFileSync(manifestPath, 'utf8');
    if (manifest.includes(BEGIN_MARKER)) return false;

    const entry = [
        '',
        BEGIN_MARKER,
        "server_script 'lc_itemcreator_bridge.lua'",
        "client_script 'lc_itemcreator_bridge.client.lua'",
        END_MARKER,
        '',
    ].join('\n');

    fs.writeFileSync(manifestPath, manifest.replace(/\s*$/, '') + entry, 'utf8');
    log('INFO', 'Added the LC_itemcreator bridge entries to ox_inventory/fxmanifest.lua.');
    return true;
}

function startInstallation() {
    log('INFO', 'Trying the opt-in ox_inventory bridge installation.');

    if (GetResourceState(TARGET) === 'missing') {
        log('ERROR', 'ox_inventory was not found. Follow installation/README.md.');
        return false;
    }

    try {
        const sourceRoot = GetResourcePath(RESOURCE);
        const targetRoot = GetResourcePath(TARGET);
        let changed = false;

        changed = installFile(sourceRoot, targetRoot, 'lc_itemcreator_bridge.lua') || changed;
        changed = installFile(sourceRoot, targetRoot, 'lc_itemcreator_bridge.client.lua') || changed;
        changed = installManifest(targetRoot) || changed;

        if (changed) {
            log('INFO', 'Integration installed. Restart ox_inventory once before using LC_itemcreator.');
        } else {
            log('INFO', 'Integration is already installed; no files were changed.');
        }

        return true;
    } catch (error) {
        log('ERROR', `Automatic installation failed: ${error.message}`);
        log('ERROR', 'Follow LC_itemcreator/installation/README.md to install manually.');
        return false;
    }
}

exports('startInstallation', startInstallation);
