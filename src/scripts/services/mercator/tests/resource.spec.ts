import * as assert from "assert";
import { expect } from "chai";
import "mocha";
import { Resource } from "../resource";

const resources = [
    "/subscriptions/subscription-01/resourceGroups/resourceGroup-01/providers/provider-01/type-01/name-01",
    "/subscriptions/subscription-02/resourceGroups/resourceGroup-02/providers/provider-02/type-02/name-02",
];

describe("Resource.constructor", () => {
    it("should fail with invalid uri", () => {
        expect(() => new Resource(null)).to.throw(assert.AssertionError);
        expect(() => new Resource(undefined)).to.throw(assert.AssertionError);
    });
    it("should construct", () => {
        for (const uri of resources) {
            const resource = new Resource(uri);
            expect(resource.uri).to.equal(uri);
            expect(resource.subscriptionId).to.equal(resource.uri.split("/")[2]);
            expect(resource.resourceGroup).to.equal(resource.uri.split("/")[4]);
            expect(resource.provider).to.equal(resource.uri.split("/")[6]);
            expect(resource.type).to.equal(resource.uri.split("/")[7]);
            expect(resource.name).to.equal(resource.uri.split("/")[8]);
        }
    });
});
