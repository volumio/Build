#!/usr/local/bin/node

//Volumio Network Manager - Copyright Michelangelo Guarise - Volumio.org

// Time needed to settle some commands sent to the system like ifconfig
var debug = false;

var settleTime = 3000;
var fs = require('fs-extra')
var thus = require('child_process');
var wlan = "wlan0";
var dhcpd = "dhcpd";
var dhclient = "/usr/bin/sudo /sbin/dhcpcd";
var justdhclient = "/usr/bin/sudo /sbin/dhcpcd";
var starthostapd = "systemctl start hotspot.service";
var stophostapd = "systemctl stop hotspot.service";
var ifconfigHotspot = "ifconfig " + wlan + " 192.168.211.1 up";
var ifconfigWlan = "ifconfig " + wlan + " up";
var ifdeconfig = "sudo ip addr flush dev " + wlan + " && sudo ifconfig " + wlan + " down";
var execSync = require('child_process').execSync;
var ifconfig = require('/volumio/app/plugins/system_controller/network/lib/ifconfig.js');
var conf = {};
if (debug) {
	var wpasupp = "wpa_supplicant -d -s -B -Dnl80211,wext -c/etc/wpa_supplicant/wpa_supplicant.conf -i" + wlan;
} else {
	var wpasupp = "wpa_supplicant -s -B -Dnl80211,wext -c/etc/wpa_supplicant/wpa_supplicant.conf -i" + wlan;
}

function kill(process, callback) {
    var all = process.split(" ");
    var process = all[0];
    var command = 'kill `pgrep -f "^' + process + '"` || true';
    logger("killing: " + command);
    return thus.exec(command, callback);
}



function launch(fullprocess, name, sync, callback) {
    if (sync) {
        var child = thus.exec(fullprocess, {}, callback);
        child.stdout.on('data', function(data) {
            logger(name + 'stdout: ' + data);
        });

        child.stderr.on('data', function(data) {
            logger(name + 'stderr: ' + data);
        });

        child.on('close', function(code) {
            logger(name + 'child process exited with code ' + code);
        });
    } else {
        var all = fullprocess.split(" ");
        var process = all[0];
        if (all.length > 0) {
            all.splice(0, 1);
        }
        logger("launching " + process + " args: ");
        logger(all);
        var child = thus.spawn(process, all, {});
        child.stdout.on('data', function(data) {
            logger(name + 'stdout: ' + data);
        });

        child.stderr.on('data', function(data) {
            logger(name + 'stderr: ' + data);
        });

        child.on('close', function(code) {
            logger(name + 'child process exited with code ' + code);
        });
        callback();
    }

    return
}


function startHotspot() {
    stopHotspot(function(err) {
        if (conf != undefined && conf.enable_hotspot != undefined && conf.enable_hotspot.value != undefined && !conf.enable_hotspot.value) {
            console.log('Hotspot is disabled, not starting it');
            launch(ifconfigWlan, "configwlanup", true, function(err) {
                logger("ifconfig " + err);
            });
        } else {
            launch(ifconfigHotspot, "confighotspot", true, function(err) {
                logger("ifconfig " + err);
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
        logger("Conf " + ifdeconfig);
        launch(wpasupp, "wpa supplicant", false, function(err) {
            logger("wpasupp " + err);
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
var totalSecondsForConnection = 20;
var pollingTime = 1;
var actualTime = 0;
var apstopped = 0

function startFlow() {
    try {
        var netconfigured = fs.statSync('/data/configuration/netconfigured');
    } catch (e) {
        var directhotspot = true;
    }

    if (conf != undefined && conf.wireless_enabled != undefined && conf.wireless_enabled.value != undefined && !conf.wireless_enabled.value) {
        console.log('Wireless Networking DISABLED, not starting wireless flow');
    } else if (directhotspot){
        startHotspot(function () {

        });
    } else {
        console.log("Start wireless flow");
        startAP(function () {
            console.log("Start ap");
            lesstimer = setInterval(function () {
                actualTime += pollingTime;
                if (wpaerr > 0) {
                    actualTime = totalSecondsForConnection + 1;
                }
                
                if (actualTime > totalSecondsForConnection) {
                    console.log("Overtime, starting plan B");
                    if (conf != undefined && conf.hotspot_fallback != undefined && conf.hotspot_fallback.value != undefined && conf.hotspot_fallback.value) {
                        console.log('STARTING HOTSPOT');
                        apstopped = 1;
                        clearTimeout(lesstimer);
                        stopAP(function () {
                            setTimeout(function () {
                                startHotspot(function () {


                                });
                            }, settleTime);
                        });
                    } else {
                        apstopped = 0;
                        wstatus("ap");
                        clearTimeout(lesstimer);

                    }

                } else {
                    var SSID = undefined;
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


if ( ! fs.existsSync("/sys/class/net/" + wlan + "/operstate") ) {
    console.log("WIRELESS: No wireless interface, exiting");
    process.exit(1);
}

if (process.argv.length < 2) {
    console.log("Use: start|stop");
} else {
    var args = process.argv[2];
    console.log('WIRELESS DAEMON: ' + args);
    try {
        conf = fs.readJsonSync('/data/configuration/system_controller/network/config.json');
        console.log('WIRELESS: Loaded configuration');
        if (debug) {
        	console.log('WIRELESS CONF: ' + JSON.stringify(conf))
	}
    } catch (e) {
        console.log('WIRELESS: First boot');
        conf = fs.readJsonSync('/volumio/app/plugins/system_controller/network/config.json');
    }

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

function logger(msg) {
    if (debug) {
        console.log(msg)
    }
}
