import * as util from "util";

import {
    IStateEntity,
} from "./typings";

import { ApiClient } from "./apiClient";
import { DataModel } from "./dataModel";
import { RowEntity } from "./rowEntity";

class StateEntity extends RowEntity implements IStateEntity {
    public static generateRowKey(id: string, type: string, tag: string): string {
        return util.format("%s$$%s$$%s",
            type,
            id.replace(/[\/]/g, "--"),
            tag).toLowerCase();
    }

    public static fromEntity(entity): StateEntity {
        return new StateEntity(
            entity.Id._,
            entity.Type._ as string,
            entity.Tag._,
            entity.CreatedWhen._,
            entity.State._,
            entity[".metadata"],
        );
    }

    public id: string;
    public type: string;
    public createdWhen: Date;
    public tag: string;
    public state: string;
    constructor(
        id: string, type: string, tag: string, createdWhen: Date, state: string, metadata?: object) {
        super(DataModel.StateEntitiesPK, StateEntity.generateRowKey(id, type, tag), metadata);
        this.id = id;
        this.type = type;
        this.createdWhen = createdWhen;
        this.tag = tag;
        this.state = state;
    }

    public toEntity(etag?: string) {
        const generator = ApiClient.generator();
        const entity = {
            CreatedWhen: generator.DateTime(this.createdWhen),
            Id: generator.String(this.id),
            PartitionKey: generator.String(this.partitionKey),
            RowKey: generator.String(this.rowKey),
            State: generator.String(this.state),
            Tag: generator.String(this.tag),
            Type: generator.String(this.type),
        };
        if (this.metadata !== undefined && this.metadata !== null) {
            entity[".metadata"] = this.metadata;
            if (etag !== undefined) {
                entity[".metadata"].etag = etag;
            }
        }
        return entity;
    }
}

export { StateEntity };
