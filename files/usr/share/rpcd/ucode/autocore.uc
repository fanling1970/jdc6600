/*
 * Copyright (C) 2021-2025 ImmortalWrt
 */

'use strict';

function read_file(path) {
	let f;
	try {
		f = new File(path, "r");
		let s = f.read();
		f.close();
		return s.trim();
	} catch(e) {
		return null;
	}
}

function get_cpu_temp() {
	/* IPQ60xx 优先读取 thermal_zone0 */
	let val = read_file("/sys/class/thermal/thermal_zone0/temp");
	if (val) {
		let t = Number(val);
		if (t > 0)
			return Math.round(t / 1000);
	}
	return null;
}

function get_sys_info() {
	let cpuModel = null;
	let cpuFreq = null;
	let memTotal = null;
	let memFree = null;
	let memBuff = null;

	let cpuinfo = read_file("/proc/cpuinfo");
	if (cpuinfo) {
		let m = cpuinfo.match(/model name\s*:\s*(.+)/);
		if (m) cpuModel = m[1];
	}

	let meminfo = read_file("/proc/meminfo");
	if (meminfo) {
		let m;
		m = meminfo.match(/MemTotal:\s*(\d+)/);
		if(m) memTotal = Number(m[1]);
		m = meminfo.match(/MemFree:\s*(\d+)/);
		if(m) memFree = Number(m[1]);
		m = meminfo.match(/Buffers:\s*(\d+)/);
		if(m) memBuff = Number(m[1]);
	}

	return {
		cpu_model: cpuModel,
		cpu_temp: get_cpu_temp(),
		mem_total: memTotal,
		mem_free: memFree,
		mem_buff: memBuff
	};
}

module.exports = {
	get_sys_info: get_sys_info,
	get_cpu_temp: get_cpu_temp
};
