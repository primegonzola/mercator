import { expect } from "chai";
import "mocha";
import { StateEntity } from "../stateEntity";

const rows = [
    new StateEntity("id-01", "type-01", "tag-01", new Date(2001, 1), "state-01", { data: "metadata-01" }),
    new StateEntity("id-02", "type-02", "tag-02", new Date(2002, 2), "state-02", { data: "metadata-02" }),
];

type metadata = {
    data: string;
};

describe("StateEntity.constructor", () => {
    it("should construct with defaults", () => {
        for (const row of rows) {
            const target = new StateEntity(
                row.id,
                row.type,
                row.tag,
                row.createdWhen,
                row.state,
            );
            expect(target.id).to.equal(row.id);
            expect(target.type).to.equal(row.type);
            expect(target.tag).to.equal(row.tag);
            expect(target.createdWhen).to.equal(row.createdWhen);
            expect(target.state).to.equal(row.state);
            expect(target.metadata).to.equal(undefined);
        }
    });
    it("should construct without defaults", () => {
        for (const row of rows) {
            const target = new StateEntity(
                row.id,
                row.type,
                row.tag,
                row.createdWhen,
                row.state,
                row.metadata);
            expect((target.metadata as metadata).data).to.equal((row.metadata as metadata).data);
        }
    });
});
