#!/usr/local/bin/node

let child_process = require('child_process');
let fs = require('fs');

class Program {
	constructor(cmd, args) {
		console.log(`Executing program ${cmd} [ ${args} ]`)
		let program = child_process.spawnSync(cmd, args);
		let exitCode = program.status;
		if ( ! exitCode) {
			if (program.signal || program.error)
				exitCode = -1;
		}
		for (let [buffer, name] of [
			// Do not bother printing the content of stdout
			// since it is going to be returned to the caller.
			//
			// [program.stdout, 'stdout'],
			[program.stderr, 'stderr']]) {
			let output = buffer.toString().trim();
			for (let line of this._lines_(output))
				console.log(`${cmd} ${name}: ${line}`)
		}

		this.exitCode = exitCode;
		this.stdout = program.stdout.toString().trim();
	}

	* _lines_(text) {
		let posn = 0;
		while (text) {
			let next = text.indexOf('\n', posn)
			if (next == -1) {
				yield text.substring(posn);
				break;
			}
			yield text.substring(posn, next);
			posn = next + 1;
			if (posn == text.length)
				break;
		}
	}
}

class NetworkInterface {
	constructor(name, wlan) {
		this.name = name;
		this.timeout = undefined;
		this.callback = undefined;
		this.enabled = true;
		this.running = false;
		this.wlan = wlan;
	}

	destructor() {
		this.disable();
		if (this.running)
			this._stopInterface();
	}

	enable() {
		this.enabled = true;
	}

	disable() {
		this.enabled = false;
	}

	_startInterface() {
		console.log(`Starting ${this.name} network`);
		this._start();
		this.running = true;
	}

	_stopInterface() {
		console.log(`Stopping ${this.name} network`);
		this._stop();

		let callback = this.callback;
		clearInterval(this.timeout);
		this.timeout = undefined;
		this.callback = undefined;
		this.running = false;

		if (this.enabled)
			callback();
	}

	_checkPeriodically(period, callback) {
		console.log(`Checking ${this.name} every ${period}s`);
		this.callback = callback;
		this.timeout = setInterval(
			function () {
				console.log(
					`Checking ${this.name}`);
				if ( ! this._check())
					this._stopInterface();
			}.bind(this), 1000 * period);
	}

	run(period, callback) {
		if ( ! this.enabled) {
			setImmediate(callback);
		} else {
			this._startInterface();
			this._checkPeriodically(period, callback);
		}
	}

	_inUse(ipAddress) {
                let ss = new Program(
                        '/bin/ss', [
                        '-n', 'state', 'established', 'src', ipAddress]);
                console.log(`${this.name} connections `
                        + `exit code ${ss.exitCode} `
                        + `[ ${ss.stdout} ]`);
                let nlPosition = ss.stdout.indexOf('\n');
                console.log(`${this.name} active connection at ${nlPosition}`);
		return nlPosition > 1;
	}
}

class WifiHotspot extends NetworkInterface {
	constructor(wlan, ipAddress, dhcpRange) {
		super('Wifi Hotspot', wlan);
		this.ipAddress = ipAddress;
		this.hostIP = ipAddress.split('/')[0];

		this._reset();

		// Write the configuration of the DHCP and DNS services
		// into /var/run since there is no point persisting the
		// settings beyond the lifetime of the hotspot itself.

		fs.writeFileSync(
			'/var/run/hotspot-dnsmasq.conf', [
			`address=/#/${this.hostIP}`,
			`dhcp-leasefile=/var/run/dnsmasq.leases`,
			`dhcp-range=${dhcpRange}`,
			`dhcp-option=option:router,${this.hostIP}`,
			`dhcp-option=option:domain-name,".local"`,
			`dhcp-option=option:dns-server,${this.hostIP}`].join(
				'\n') + '\n',
			{ mode: 0o644 });
	}

	_reset() {
		let ifconfig = new Program(
			'/sbin/ifconfig', [
			this.wlan,
			'0.0.0.0', 'down']);
		console.log(`${this.name} deconfigured `
			+ `exit code ${ifconfig.exitCode} `
			+ `[ ${ifconfig.stdout} ]`);

		let hotspot = new Program(
			'/bin/systemctl', [
			'stop', 'wireless-hotspot']);
		console.log(`${this.name} stopped `
			+ `exit code ${hotspot.exitCode} `
			+ `[ ${hotspot.stdout} ]`);
	}

	_start() {
		let ifconfig = new Program(
			'/sbin/ifconfig', [
			this.wlan,
			this.ipAddress, 'up']);
		console.log(`${this.name} configured `
			+ `exit code ${ifconfig.exitCode} `
			+ `[ ${ifconfig.stdout} ]`);

		let hotspot = new Program(
			'/bin/systemctl', [
			'start', 'wireless-hotspot']);
		console.log(`${this.name} started `
			+ `exit code ${hotspot.exitCode} `
			+ `[ ${hotspot.stdout} ]`);
	}

	_check() {
		// Check if there are any established stations
		// connected to the hotspot. The hotspot can be
		// torn down if none are found.

                let hostapdcli = new Program(
			'/usr/sbin/hostapd_cli', [
			'-i', this.wlan, 'all_sta' ]);
                console.log(`${this.name} connections `
                        + `exit code ${hostapdcli.exitCode} `
                        + `[ ${hostapdcli.stdout} ]`);

		return hostapdcli.exitCode == 0
			&& (hostapdcli.stdout || false);
	}

	_stop() {
		this._reset();
	}
}

class WifiClient extends NetworkInterface {
	constructor(wlan) {
		super('Wifi Client', wlan);
		this._reset();
	}

	_reset() {
		let client = new Program(
			'/bin/systemctl', [
			'stop', 'wireless-client']);
		console.log(`${this.name} stopped `
			+ `exit code ${client.exitCode} `
			+ `[ ${client.stdout} ]`);

		this.ipAddress = undefined;
	}

	_start() {
		let client = new Program(
			'/bin/systemctl', [
			'start', 'wireless-client']);
		console.log(`${this.name} started `
			+ `exit code ${client.exitCode} `
			+ `[ ${client.stdout} ]`);
	}

	_check() {
		// Check if an IP address is assigned to the access point.
		// Tear down the access point if an address could not
		// be found. This typically means that either the
		// access point could not be joined, or that no IP
		// address could be leased.

		let ip = new Program(
			'/bin/ip', [
			'-f', 'inet',
			'addr', 'show', this.wlan]);
		console.log(`${this.name} interface address ${ip.stdout}`);

		let ipAddress = undefined;
		for (let line of ip.stdout.split('\n')) {
			line = line.trim();
			if (line.startsWith('inet ')) {
				ipAddress = line.split(' ')[1].split('/')[0];
			}
		}

		if (this.ipAddress != ipAddress || ip.exitCode) {
			this.ipAddress = ipAddress;
			console.log(`${this.name} interface check `
				+ `exit code ${ip.exitCode} `
				+ `address ${this.ipAddress}`)
		}

                // Also require that there are established TCP sessions using
                // the IP address of the access point.

		return ip.exitCode == 0
			&& this.ipAddress
			&& this._inUse(this.ipAddress);
	}

	_stop() {
		this._reset();
	}
}

console.log('Initialising wireless service');

let wlan = 'wlan0';

// Choose an IP network for the hotspot that will not collide with any
// properly configured production network address assignment. Use the
// address assignment from RFC2544 since those addresses should only
// ever be present for networks under test.

let hotspotAddress = '198.18.0.1/15'; // RFC2544 to avoid address collision
let hotspotDhcpRange = '198.18.0.2,198.18.0.100';

let hotspot = new WifiHotspot(wlan, hotspotAddress, hotspotDhcpRange);
let client = new WifiClient(wlan);

let config;
try {
	config = require(
		'/data/configuration/system_controller/network/config.json');
} catch (err) {
	if (err.code != 'MODULE_NOT_FOUND')
		throw err;
}

if (config != undefined
	&& config.enable_hotspot != undefined
	&& config.enable_hotspot.value != undefined) {

	// Setting   Hotspot   Client
	//
	// false     disabled  enabled
	// 'off'     disabled  enabled
	// 'on'      enabled   disabled
	// 'auto'    enabled   enabled
	// true      enabled   enabled

	let enable_hotspot = config.enable_hotspot.value;
	if (enable_hotspot) {
		enable_hotspot = enable_hotspot.toString().toLowerCase();
		if (enable_hotspot === 'off')
			enable_hotspot = false;
		else if (enable_hotspot === 'on') {
			console.log('Client disabled');
			client.disable();
		}
	}

	if ( ! enable_hotspot) {
		console.log('Hotspot disabled');
		hotspot.disable();
	}
}

function runNetwork() {

	// Even when running the hotspot or client only, periodically check
	// if the established network is viable, and restart it if there
	// are no signs of activity. Check more frequently when running
	// both network types to reduce the time a user might see as
	// a network outage.

	let hotspotOnlyPeriod = 60;
	let clientOnlyPeriod = 60;

	let hotspotPeriod = 15;
	let clientPeriod = 30;

	function runClientOnly() {
		client.run(clientOnlyPeriod, runClientOnly);
	}

	function runHotspotOnly() {
		hotspot.run(hotspotOnlyPeriod, runHotspotOnly);
	}

	function runHotspotAndClient() {
		hotspot.run(hotspotPeriod, function () {
			client.run(clientPeriod, runHotspotAndClient);
			});
	}

	if ( ! hotspot.enabled) {
		console.log('Selecting client only');
		runClientOnly();
	} else if ( ! client.enabled) {
		console.log('Selecting hotspot only');
		runHotspotOnly();
	} else {
		console.log('Selecting hotspot and client');
		runHotspotAndClient();
	}
}

function stopService() {
	console.log('');
	console.log('Stopping wireless service');
	hotspot.destructor();
	client.destructor();
}

function killService(sigName) {
	stopService();
	process.removeAllListeners(sigName);
	process.kill(process.pid, sigName);
	process.removeAllListeners('exit');
	process.exit(1);
}

function exitService(code) {
	console.log('');
	if (code)
		console.log(`Wireless service exit ${code}`);
	else {
		console.log('Unexpected wireless service exit');
		code = 1;
	}
	process.exit(code);
}

// Continue running the service until there is a signal received that
// requests the service to terminate. Signals are handled synchronously
// with respect to other activities, ensuring that the wireless services
// are shut down before this service exits.

for (let sigName of ['SIGINT', 'SIGTERM'])
	process.on(sigName, function () { killService(sigName); });
process.on('exit', exitService);

console.log('Running wireless service');
runNetwork();
