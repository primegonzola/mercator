import {
    IStatusTarget,
} from "./typings";

class StatusTarget implements IStatusTarget {
    public static getByResourceId(id: string): StatusTarget {
        if (id !== undefined && id !== null) {
            for (const target of StatusTarget.targets) {
                if (target.resources !== undefined && target.resources !== null) {
                    for (const resource of target.resources) {
                        if (resource.toLowerCase() === id.toLowerCase()) {
                            return target;
                        }
                    }
                }
            }
        }
        // nothing there
        return null;
    }

    private static targetList: IStatusTarget[];
    public name: string;
    public type: string;
    public resources: string[];
    public grace: number;
    public minimum: number;
    public expiration: number;
    public unhealthy: string;

    constructor(
        name: string, type: string,
        resources: string[], unhealthy: string,
        expiration: number, grace: number = 0, minimum: number = 1) {
        this.name = name;
        this.type = type;
        this.resources = resources;
        this.unhealthy = unhealthy;
        this.expiration = expiration;
        this.grace = grace;
        this.minimum = minimum;
    }

    public static get targets(): IStatusTarget[] {
        if (StatusTarget.targetList === undefined || StatusTarget.targetList === null) {
            const variable = global.process.env.STATUS_TARGETS;
            StatusTarget.targetList =
                (variable !== undefined && variable !== null && variable !== "") ? JSON.parse(variable) : [];
        }
        return StatusTarget.targetList;
    }
}

export { StatusTarget };
