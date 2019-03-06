import * as util from "util";

import {
    IStatusEntity,
} from "./typings";

import { ApiClient } from "./apiClient";
import { DataModel } from "./dataModel";
import { RowEntity } from "./rowEntity";

class StatusEntity extends RowEntity implements IStatusEntity {
    public static generateRowKey(id: string, type: string, tag: string): string {
        return util.format("%s$$%s$$%s",
            type,
            id.replace(/[\/]/g, "--"),
            tag).toLowerCase();
    }

    public static fromEntity(entity): StatusEntity {
        return new StatusEntity(
            entity.Id._,
            entity.Type._,
            entity.Tag._,
            entity.Category._,
            entity.ChangedWhen._,
            entity.Status._,
            JSON.parse(entity.Data._),
            entity.Timestamp._,
            entity[".metadata"],
        );
    }

    public id: string;
    public category: string;
    public data: any;
    public tag: string;
    public type: string;
    public changedWhen: Date;
    public status: string;
    public timestamp: Date;
    constructor(
        id: string,
        type: string,
        tag: string,
        category: string,
        changedWhen: Date,
        status: string,
        data: any,
        timestamp?: Date,
        metadata?: object) {
        super(DataModel.StatusEntitiesPK, StatusEntity.generateRowKey(id, type, tag), metadata);
        this.id = id;
        this.type = type;
        this.category = category;
        this.tag = tag;
        this.changedWhen = changedWhen;
        this.status = status;
        this.data = data;
        this.timestamp = timestamp;
    }

    public toEntity(etag?: string) {
        const generator = ApiClient.generator();
        const entity = {
            Category: generator.String(this.category),
            ChangedWhen: generator.DateTime(this.changedWhen),
            Data: generator.String(JSON.stringify(this.data)),
            Id: generator.String(this.id),
            PartitionKey: generator.String(this.partitionKey),
            RowKey: generator.String(this.rowKey),
            Status: generator.String(this.status),
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

export { StatusEntity };
