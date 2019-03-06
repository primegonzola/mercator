import {
    IRowEntity,
} from "./typings";

class RowEntity implements IRowEntity {
    public partitionKey: string;
    public rowKey: string;
    public metadata?: object;
    constructor(partitionKey: string, rowKey: string, metadata?: object) {
        this.partitionKey = partitionKey;
        this.rowKey = rowKey;
        this.metadata = metadata;
    }
}

// export
export { RowEntity };
