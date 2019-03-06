import { expect } from "chai";
import "mocha";
import { RowEntity } from "../rowEntity";

const rows = [
    new RowEntity("partition-01", "rowkey-01", { data: "metadata-01" }),
    new RowEntity("partition-02", "rowkey-02", { data: "metadata-02" }),
];

type metadata = {
    data: string;
};

describe("RowEntity.constructor", () => {
    it("should construct with defaults", () => {
        for (const row of rows) {
            const target = new RowEntity(row.partitionKey, row.rowKey);
            expect(target.rowKey).to.equal(row.rowKey);
            expect(target.partitionKey).to.equal(row.partitionKey);
            expect(target.metadata).to.equal(undefined);
        }
    });
    it("should construct without defaults", () => {
        for (const row of rows) {
            const target = new RowEntity(row.partitionKey, row.rowKey, row.metadata);
            expect(target.rowKey).to.equal(row.rowKey);
            expect(target.partitionKey).to.equal(row.partitionKey);
            expect((target.metadata as metadata).data).to.equal((row.metadata as metadata).data);
        }
    });
});
