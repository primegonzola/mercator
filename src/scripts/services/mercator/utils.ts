import { ApiClient } from "./apiClient";

/**
 * The Utils class provides static helper  methods.
 *
 * @class
 * @public
 *
 */
class Utils {
    public static isDebug(): boolean {
        // check if debug is set
        return global.process.env.MERCATOR_DEBUG_MODE !== undefined &&
            global.process.env.MERCATOR_DEBUG_MODE !== null &&
            global.process.env.MERCATOR_DEBUG_MODE.toLowerCase() === "true";
    }

    public static getVariable(name: string, def: any): string {
        const val = global.process.env[name];
        if (val === undefined || val === null) {
            return def;
        }
        return val;
    }

    public static findObject(owners: any[], name: string, value: any): any {
        for (const owner of owners) {
            if (owner[name] !== undefined && owner[name] !== null) {
                if (owner[name] === value) {
                    return owner;
                }
            }
        }
        return null;
    }

    public static isNumeric(n): boolean {
        return !isNaN(parseFloat(n)) && isFinite(n);
    }

    public static pad(target: string, size: number): string {
        let s = target;
        while (s.length < (size || 2)) { s = "0" + s; }
        return s;
    }

    // see https://github.com/gbowerman/vmsstools/tree/master/vmssvmname
    public static hostNameToInstanceId(name): number {
        // get last 6 characters and remove leading zeroes
        let id = 0;
        let multiplier = 1;
        const hexatrig = name.substring(name.length - 6).replace(/^(0+)/g, "");
        const reverse = hexatrig.split("").reverse().join("");
        // reverse string and process each char
        for (let i = 0; i < reverse.length; i++) {
            const c = reverse.charAt(i);
            if (Utils.isNumeric(c)) {
                id += parseInt(c, 10) * multiplier;
            } else {
                id += (c.charCodeAt(0) - 55) * multiplier;
            }
            multiplier *= 36;
        }
        return id;
    }

    // see https://github.com/gbowerman/vmsstools/tree/master/vmssvmname
    public static instanceToHostName(prefix: string, id: number): string {
        let hexatrig = "";
        // convert decimal vmid to hexatrigesimal base36
        while (id > 0) {
            let char = "";
            const mod = id % 36;
            if (mod > 9) {
                char = String.fromCharCode(mod + 55);
            } else {
                char = String.fromCharCode(mod);
            }
            hexatrig = char + hexatrig;
            id = Math.floor(id / 36);
        }
        return prefix + Utils.pad(hexatrig, 6);
    }

    public static createTableGenerator(): any {
        return ApiClient.generator();
    }
}

// export
export { Utils };
