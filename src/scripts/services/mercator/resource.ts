// our main imports
import * as assert from "assert";
import * as util from "util";
import { IResource } from "./typings";

/**
 * The Resource class abstracts an Azure resource.
 *
 * @class
 * @public
 * @requires util
 * @requires assert
 * @property {string} subscriptionId - The subscription id of the resource.
 * @property {string} provider - The provider of the resource.
 * @property {string} type - The type of the resource.
 * @property {string} name - The name of the resource.
 * @property {string} uri - The uri of the resource.
 * @example
 * //
 * // create a new resource using the specified uri
 * //
 * let resource = new Resource('/mysubscriptionid/Microsoft.Compute/virtualMachineScaleSet/myscaleset');
 * //
 * // show the subscription id
 * //
 * context.log.info(resource.subscriptionId);
 *
 */
class Resource implements IResource {
    private resourceUri: string;
    /**
     * @constructs
     * Creates a new Resource instance using the provided resource uri.
     *
     * @param {string} resourceUri - The uri of the resource.
     *
     */
    constructor(resourceUri: string) {
        // check incoming parameters
        assert(resourceUri !== null, "resourceUri argument cannot be null");
        assert(resourceUri !== undefined, "resourceUri argument cannot be undefined");
        assert.equal(typeof (resourceUri), "string", "resourceUri argument should be a string");
        // init
        this.resourceUri = resourceUri;
    }

    get subscriptionId(): string {
        return this.resourceUri.split("/")[2];
    }

    get resourceGroup(): string {
        return this.resourceUri.split("/")[4];
    }

    get provider(): string {
        return this.resourceUri.split("/")[6];
    }

    get type(): string {
        return this.resourceUri.split("/")[7];
    }

    get name(): string {
        return this.resourceUri.split("/")[8];
    }

    get uri(): string {
        return util.format("/subscriptions/%s/resourceGroups/%s/providers/%s/%s/%s",
            this.subscriptionId, this.resourceGroup, this.provider, this.type, this.name);
    }
}

// export
export { Resource };
