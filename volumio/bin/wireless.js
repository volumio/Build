#!/usr/local/bin/node

//Volumio Network Manager - Copyright Michelangelo Guarise - Volumio.org

// Time needed to settle some commands sent to the system like ifconfig
var settleTime = 3000;
var fs = require('fs-extra')
var thus = require('child_process');
var wlan = "wlan0";
var dhcpd = "dhcpd";
var dhclient = "/usr/bin/sudo /sbin/dhcpcd";
var justdhclient = "/usr/bin/sudo /sbin/dhcpcd";
var wpasupp = "wpa_supplicant -d -s -B -Dnl80211,wext -c/etc/wpa_supplicant/wpa_supplicant.conf -i" + wlan;
var starthostapd = "systemctl start hotspot.service";
var stophostapd = "systemctl stop hotspot.service";
var ifconfigHotspot = "ifconfig " + wlan + " 192.168.211.1 up";
var ifconfigWlan = "ifconfig " + wlan + " up";
var ifdeconfig = "sudo ip addr flush dev " + wlan + " && sudo ifconfig " + wlan + " down";
var execSync = require('child_process').execSync;

function kill(process, callback) {
	var all = process.split(" ");
	var process = all[0];
	var command = 'kill `pgrep -f "^' + process + '"` || true';
	console.log("killing: " + command);
	return thus.exec(command, callback);
}



function launch(fullprocess, name, sync, callback) {
	if (sync) {
		var child = thus.exec(fullprocess, {}, callback);
		child.stdout.on('data', function(data) {
			console.log(name + 'stdout: ' + data);
		});

		child.stderr.on('data', function(data) {
			console.log(name + 'stderr: ' + data);
		});

		child.on('close', function(code) {
			console.log(name + 'child process exited with code ' + code);
		});
	} else {
		var all = fullprocess.split(" ");
		var process = all[0];
		if (all.length > 0) {
			all.splice(0, 1);
		}
		console.log("launching " + process + " args: ");
		console.log(all);
		var child = thus.spawn(process, all, {});
		child.stdout.on('data', function(data) {
			console.log(name + 'stdout: ' + data);
		});

		child.stderr.on('data', function(data) {
			console.log(name + 'stderr: ' + data);
		});

		child.on('close', function(code) {
			console.log(name + 'child process exited with code ' + code);
		});
		callback();
	}

	return
}


function startHotspot() {
	stopHotspot(function(err) {
		var hotspotenabled = true;
		try {
			var hotspotjson = fs.readJsonSync('/data/configuration/system_controller/network/config.json', {throws: false});
		} catch(e) {
			console.log('First boot, starting Hotspot');
			launch(ifconfigHotspot, "confighotspot", true, function(err) {
			console.log("ifconfig " + err);
			launch(starthostapd,"hotspot" , false, function() {
				wstatus("hotspot");
			});
		});
		}

               if (hotspotjson != undefined && hotspotjson.enable_hotspot != undefined && hotspotjson.enable_hotspot.value != undefined && !hotspotjson.enable_hotspot.value) {
		   			console.log('Hotspot is disabled, not starting it');
				    launch(ifconfigWlan, "configwlanup", true, function(err) {
				   	console.log("ifconfig " + err);
					});
		} else {

		launch(ifconfigHotspot, "confighotspot", true, function(err) {
			console.log("ifconfig " + err);
			launch(starthostapd,"hotspot" , false, function() {
				wstatus("hotspot");
			});
		});
		}
	});
}

function stopHotspot(callback) {
	launch(stophostapd, "stophotspot" , true, function(err) {
		launch(ifdeconfig, "ifdeconfig", true, callback);
	});
}

function startAP(callback) {
	console.log("Stopped hotspot (if there)..");
	launch(ifdeconfig, "ifdeconfig", true,  function(err) {
		console.log("Conf " + ifdeconfig);
		launch(wpasupp, "wpa supplicant", false, function(err) {
			console.log("wpasupp " + err);
			wpaerr = err;
			try {
				dhclient = fs.readFileSync('/data/configuration/wlanstatic', 'utf8');
				console.log("FIXED IP");
			} catch (e) {
				console.log("DHCP IP ");
			}
			launch(dhclient,"dhclient", false, callback);
		});
	});
}

function stopAP(callback) {
	kill(justdhclient, function(err) {
		kill(wpasupp, function(err) {
			callback();
		});
	});
}
var wpaerr;
var lesstimer;
var totalSecondsForConnection = 40;
var pollingTime = 1;
var actualTime = 0;
var apstopped = 0

function startFlow() {
	try {
		var wirelessjson = fs.readJsonSync('/data/configuration/system_controller/network/config.json', {throws: false});
	} catch (e) {
		console.log('');
	}
	if (wirelessjson != undefined && wirelessjson.wireless_enabled != undefined && wirelessjson.wireless_enabled.value != undefined && !wirelessjson.wireless_enabled.value) {
		console.log('Wireless Networking DISABLED, not starting wireless flow');
	} else {
		console.log("Start wireless flow");
	startAP(function () {
		console.log("Start ap");
		lesstimer = setInterval(function () {
			actualTime += pollingTime;
			if (wpaerr > 0) actualTime = totalSecondsForConnection + 1;

			if (actualTime > totalSecondsForConnection) {
				console.log("Overtime, starting plan B");
				apstopped = 1;
				clearTimeout(lesstimer);
				stopAP(function () {
					setTimeout(function () {
						startHotspot(function () {


						});
					}, settleTime);
				});
			} else {
				var SSID = undefined;
				var ifconfig = require('wireless-tools/ifconfig');
				console.log("trying...");
				try {
					var SSID = execSync("/usr/bin/sudo /sbin/iwgetid -r", { uid: 1000, gid: 1000, encoding: 'utf8'});
					console.log('Connected to: ----'+SSID+'----');
				} catch(e) {
					//console.log('ERROR: '+e)
				}


					if (SSID != undefined) {
						ifconfig.status(wlan, function (err, ifstatus) {
							console.log("... joined AP, wlan0 IPv4 is " + ifstatus.ipv4_address + ", ipV6 is " + ifstatus.ipv6_address);
							if (((ifstatus.ipv4_address != undefined) &&
								(ifstatus.ipv4_address.length > "0.0.0.0".length))
								||
								((ifstatus.ipv6_address != undefined) &&
								(ifstatus.ipv6_address.length > "::".length))) {
								if (apstopped == 0) {
									console.log("It's done! AP");
									wstatus("ap");
									clearTimeout(lesstimer);
									restartAvahi();
								}
							}
						});
					}

			}
		}, pollingTime * 1000);
	});
}
}

function stop(callback) {
	stopAP(function() {
		stopHotspot(callback);
	});
}


if (process.argv.length < 2) {
	console.log("Use: start|stop");
} else {
	var args = process.argv[2];
	console.log(args);

	switch (args) {
		case "start":
			console.log("Cleaning previous...");
                        stopHotspot(function () {
                        stopAP(function() {
                                console.log("Stopped aP");
                                startFlow();
                        })});
			break;
		case "stop":
			stopAP(function() {});
			break;
		case "test":
			wstatus("test");
			break;
	}
}

function wstatus(nstatus) {
	thus.exec("echo " + nstatus + " >/tmp/networkstatus", null);
}

function restartAvahi() {
	//thus.exec("/bin/systemctl restart avahi-daemon");
}
