import { expect } from "chai";
import "mocha";
import { StatusTarget } from "../applicationModel";

const rows = [
    new StatusTarget(
        "target-01",
        "VirtualMachineSet",
        ["resource-0101", "resource-0102"], "DOWN", 100, 10, 2),
    new StatusTarget(
        "target-02",
        "VirtualMachineSet",
        ["resource-0201", "resource-0202"], "DOWN", 100, 10, 2),
];

describe("StatusTarget.constructor", () => {
    it("should construct", () => {
        for (const row of rows) {
            const target = new StatusTarget(
                row.name,
                row.type,
                row.resources,
                row.unhealthy,
                row.expiration,
                row.grace,
                row.minimum);
            expect(target.name).to.equal(row.name);
            expect(target.type).to.equal(row.type);
            expect(target.resources[0]).to.equal(row.resources[0]);
            expect(target.resources[1]).to.equal(row.resources[1]);
            expect(target.unhealthy).to.equal(row.unhealthy);
            expect(target.expiration).to.equal(row.expiration);
            expect(target.grace).to.equal(row.grace);
            expect(target.minimum).to.equal(row.minimum);
        }
    });
    it("should initialize", () => {
        // set proper env
        process.env.STATUS_TARGETS = JSON.stringify(rows);
        // verify length assuming constructor passes
        expect(StatusTarget.targets.length).to.equal(rows.length);
    });
});

describe("StatusTarget.getResourceById", () => {
    it("should return target by resource", () => {
        // set proper env
        process.env.STATUS_TARGETS = JSON.stringify(rows);
        // get targets
        const target0101 = StatusTarget.getByResourceId(rows[0].resources[0]);
        const target0102 = StatusTarget.getByResourceId(rows[0].resources[1]);
        const target0201 = StatusTarget.getByResourceId(rows[1].resources[0]);
        const target0202 = StatusTarget.getByResourceId(rows[1].resources[1]);
        // validate
        expect(target0101.name).to.equal(target0102.name);
        expect(target0201.name).to.equal(target0202.name);
    });
});
