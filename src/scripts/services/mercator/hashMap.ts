// modules come here
import * as assert from "assert";
import { IHashMap } from "./typings";

/**
 * A basic hash map allowing any object as key and value.
 * Includes iterating over contained keys, clearing all and removing single key
 *
 * @class
 * @public
 * @example
 * //
 * // create a new hashmap
 * //
 * let map = new HashMap();
 * //
 * // set a key value pair
 * //
 * map.set("mykey", "hello world");
 * //
 * // check it the key is in there
 * //
 * let exists = map.has("mykey"):
 * //
 * // remove key
 * //
 * map.remove("mykey");
 */
class HashMap implements IHashMap {
    private map: object;

    /**
     * Creates a new HashMap instance.
     * @public
     * @constructs
     *
     */
    public constructor() {
        //
        // init
        //
        this.map = {};
    }

    /**
     * Checks if the specified key exists.
     *
     * @public
     * @param key {object} - The key to check for.
     * @returns {boolean} A boolean indicating if the specified key exists.
     */
    public has(key: any): boolean {
        //
        // check incoming parameters
        //
        assert(key !== null, "key argument cannot be null");
        assert(key !== undefined, "key argument cannot be undefined");
        //
        // check if there
        //
        return (this.map[JSON.stringify(key)] !== undefined) && (this.map[JSON.stringify(key)] !== null);
    }

    /**
     * Gets the value using the specified key or null if not existing.
     *
     * @public
     * @param key {object} - The key to get the value for.
     * @returns {object} The value of the specifed key or null if key does not exists.
     */
    public get(key: any) {
        //
        // check incoming parameters
        //
        assert(key !== null, "key argument cannot be null");
        assert(key !== undefined, "key argument cannot be undefined");
        //
        // see if exists and return the value or null if not existing
        //
        return this.has(key) ? this.map[JSON.stringify(key)] : null;
    }

    /**
     * Sets the value using the specified key overwriting if already existing.
     *
     * @public
     * @param key {object} - The key to set the value for.
     * @param value {object} - The value to use for the specified key.
     *
     */
    public set(key: any, value: any) {
        //
        // check incoming parameters
        //
        assert(key !== null, "key argument cannot be null");
        assert(key !== undefined, "key argument cannot be undefined");

        assert(value !== null, "value argument cannot be null");
        assert(value !== undefined, "value argument cannot be undefined");
        //
        // set the value
        //
        this.map[JSON.stringify(key)] = value;
    }

    /**
     * Removes the value using the specified key.
     *
     * @public
     * @param key {object} - The key to remove the value for.
     *
     */
    public remove(key: any) {
        //
        // check incoming parameters
        //
        assert(key !== null, "key argument cannot be null");
        assert(key !== undefined, "key argument cannot be undefined");
        //
        // check if key exists and delete it
        //
        if (this.has(key)) {
            delete this.map[JSON.stringify(key)];
        }
    }

    /**
     * The number of items in the map.
     *
     * @public
     * @returns {number} the number of items in the map.
     *
     */
    public size(): number {
        let count = 0;
        for (const key in this.map) {
            if (this.map.hasOwnProperty(key)) {
                count++;
            }
        }
        return count;
    }

    /**
     * Clears and removes all items in the map.
     * @public
     *
     */
    public clear(): void {
        for (const key in this.map) {
            if (this.map.hasOwnProperty(key)) {
                delete this.map[key];
            }
        }
    }

    /**
     * Iterates over all keys in the map.
     * @param {function(key, value)} callback invoked for each item providing the key and value.
     * @public
     */
    public each(callback: (key: any, value: any) => void) {
        if (callback !== null) {
            for (const key in this.map) {
                if (this.map.hasOwnProperty(key)) {
                    callback(JSON.parse(key), this.map[key]);
                }
            }
        }
    }
}

// export
export { HashMap };
