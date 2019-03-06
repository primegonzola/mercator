import { expect } from "chai";
import "mocha";
import { StatusEntity } from "../statusEntity";

const rows = [
    new StatusEntity(
        "id-01", "type-01", "category-1", "tag-01",
        new Date(2001, 1), "status-01", null, new Date(2002, 2), { data: "metadata-01" }),
    new StatusEntity(
        "id-02", "type-02", "category-1", "tag-02", new Date(2003, 3), "status-02",
        new Date(2004, 4), null, { data: "metadata-02" }),
];

type metadata = {
    data: string;
};

describe("StatusEntity.constructor", () => {
    it("should construct with defaults", () => {
        for (const row of rows) {
            const target = new StatusEntity(
                row.id,
                row.type,
                row.tag,
                row.category,
                row.changedWhen,
                row.status,
                row.data,
            );
            expect(target.id).to.equal(row.id);
            expect(target.type).to.equal(row.type);
            expect(target.tag).to.equal(row.tag);
            expect(target.changedWhen).to.equal(row.changedWhen);
            expect(target.status).to.equal(row.status);
            expect(target.metadata).to.equal(undefined);
            expect(target.timestamp).to.equal(undefined);
        }
    });
    it("should construct without defaults", () => {
        for (const row of rows) {
            const target = new StatusEntity(
                row.id,
                row.type,
                row.tag,
                row.category,
                row.changedWhen,
                row.status,
                row.data,
                row.timestamp,
                row.metadata,
            );
            expect((target.timestamp as Date)).to.equal(row.timestamp);
            expect((target.metadata as metadata).data).to.equal((row.metadata as metadata).data);
        }
    });
});
