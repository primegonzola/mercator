import {
    IApiClient,
    IDataModel,
    IHashMap,
    IStateEntity,
    IStatusEntity,
} from "./typings";

import { HashMap } from "./hashMap";
import { Logger } from "./logger";
import { Resource } from "./resource";
import { StateEntity } from "./stateEntity";
import { StatusEntity } from "./statusEntity";

class DataModel implements IDataModel {
    public static KeyValueTableName = "KeyValue";
    public static StateTableName = "State";
    public static StateEntitiesPK = "StateEntities";
    public static StatusTableName = "Status";
    public static StatusEntitiesPK = "StatusEntities";
    public static ConfigurationTableName = "Configuration";
    public static ConfigurationEntitiesPK = "ConfigurationEntities";

    public static async createInstance(api: IApiClient): Promise<IDataModel> {
        return Logger.enterAsync<DataModel>("DataModel.createInstance", async () => {
            // create instance
            const model = new DataModel(api);
            // init
            await model.initialize();
            // done
            return model;
        });
    }

    public api: IApiClient;

    constructor(api: IApiClient) {
        Logger.enter("DataModel.constructor", () => {
            this.api = api;
        });
    }

    public async isReady(): Promise<boolean> {
        return Logger.enterAsync<boolean>("DataModel.isReady", async () => {
            return this.isReadyState("data-model-system-state");
        });
    }

    public async isReadyState(name: string): Promise<boolean> {
        return Logger.enterAsync<boolean>("DataModel.isReadyState", async () => {
            // check if table exists
            const exists = await this.api.storage.doesTableExist(DataModel.ConfigurationTableName);
            // if not then stop here
            if (!exists) { return false; }
            // upsert
            const entity = await this.api.storage.getEntity(
                DataModel.ConfigurationTableName, DataModel.ConfigurationEntitiesPK, name);
            // check found
            return Promise.resolve(entity !== null &&
                entity.Value !== undefined && entity.Value !== null &&
                entity.Value._ === "Succeeded");
        });
    }

    public async markReadyState(name: string): Promise<void> {
        return Logger.enterAsync<void>("DataModel.markReadyState", async () => {
            // upsert
            await this.api.storage.upsertEntity(
                DataModel.ConfigurationTableName, DataModel.ConfigurationEntitiesPK, name, () => {
                    return {
                        Value: this.api.storage.createGenerator().String("Succeeded"),
                    };
                });
        });
    }

    public async fetchStateMap(): Promise<IHashMap> {
        return Logger.enterAsync<IHashMap>("DataModel.fetchStateMap", async () => {
            // fetch all current entries
            const entities = await this.readStates();
            // map them accordinly for easier traversal
            return Promise.resolve(this.mapStateEntities(entities));
        });
    }

    public async upsertState(state: IStateEntity): Promise<void> {
        return Logger.enterAsync<void>("DataModel.upsertState", async () => {
            const rowKey: string = StateEntity.generateRowKey(state.id, state.type, state.tag);
            await this.api.storage.upsertEntity(
                DataModel.StateTableName, DataModel.StateEntitiesPK, rowKey, () => {
                    return new StateEntity(
                        state.id, state.type, state.tag, state.createdWhen, state.state, state.metadata).toEntity();
                });
        });
    }

    public async readState(id: string, type: string, tag: string): Promise<IStateEntity> {
        return Logger.enterAsync<IStateEntity>("DataModel.readState", async () => {
            const rowKey: string = StateEntity.generateRowKey(id, type, tag);
            const entity = await this.api.storage.getEntity(
                DataModel.StateTableName, DataModel.StateEntitiesPK, rowKey);
            return entity !== null ? StateEntity.fromEntity(entity) : null;
        });
    }

    public async readStates(): Promise<IStateEntity[]> {
        return Logger.enterAsync<IStateEntity[]>("DataModel.readStates", async () => {
            const entities: IStateEntity[] = await this.api.storage.getEntities(
                DataModel.StateTableName, DataModel.StateEntitiesPK);
            return Promise.resolve(entities.map<IStateEntity>((entity) => {
                return StateEntity.fromEntity(entity);
            }));
        });
    }

    public async queryStatesById(id: string): Promise<IStateEntity[]> {
        return Logger.enterAsync<IStateEntity[]>("DataModel.queryStates", async () => {
            const entities: IStateEntity[] = [];
            const entries = await this.api.storage.getEntities(DataModel.StateTableName, DataModel.StateEntitiesPK);
            for (const entry of entries) {
                const entity = StateEntity.fromEntity(entry);
                if (entity.id === id) {
                    entities.push(entity);
                }
            }
            return entities;
        });
    }

    public async createStates(states: IStateEntity[]): Promise<void> {
        return Logger.enterAsync<void>("DataModel.createStates", async () => {
            this.api.storage.batchEntities(DataModel.StateTableName, states, (batch, entry) => {
                batch.insertOrReplaceEntity(entry.toEntity("*"));
            });
        });
    }

    public async updateStates(states: IStateEntity[]): Promise<void> {
        return Logger.enterAsync<void>("DataModel.updateStates", async () => {
            this.api.storage.batchEntities(DataModel.StateTableName, states, (batch, entry) => {
                batch.insertOrReplaceEntity(entry.toEntity("*"));
            });
        });
    }

    public async deleteStates(states: IStateEntity[]): Promise<void> {
        return Logger.enterAsync<void>("DataModel.deleteStates", async () => {
            this.api.storage.batchEntities(DataModel.StateTableName, states, (batch, entry) => {
                batch.deleteEntity(entry.toEntity());
            });
        });
    }

    public async queryStatusesById(id: string): Promise<IStatusEntity[]> {
        return Logger.enterAsync<IStatusEntity[]>("DataModel.queryStatusesById", async () => {
            const entities: IStatusEntity[] = [];
            const entries = await this.api.storage.getEntities(DataModel.StatusTableName, DataModel.StatusEntitiesPK);
            for (const entry of entries) {
                const entity = StatusEntity.fromEntity(entry);
                if (entity.id === id) {
                    entities.push(entity);
                }
            }
            return entities;
        });
    }

    public async readStatus(id: string, type: string, tag: string): Promise<IStatusEntity> {
        return Logger.enterAsync<IStatusEntity>("DataModel.readStatus", async () => {
            const rowKey: string = StatusEntity.generateRowKey(id, type, tag);
            const entity = await this.api.storage.getEntity(
                DataModel.StatusTableName, DataModel.StatusEntitiesPK, rowKey);
            return entity !== null ? StatusEntity.fromEntity(entity) : null;
        });
    }

    public async readStatuses(): Promise<IStatusEntity[]> {
        return Logger.enterAsync<IStatusEntity[]>("DataModel.readStatuses", async () => {
            const entities: IStatusEntity[] = await this.api.storage.getEntities(
                DataModel.StatusTableName, DataModel.StatusEntitiesPK);
            return Promise.resolve(entities.map<IStatusEntity>((entity) => {
                return StatusEntity.fromEntity(entity);
            }));
        });
    }

    public async createStatuses(states: IStatusEntity[]): Promise<void> {
        return Logger.enterAsync<void>("DataModel.createStatuses", async () => {
            this.api.storage.batchEntities(DataModel.StatusTableName, states, (batch, entry) => {
                batch.insertOrReplaceEntity(entry.toEntity("*"));
            });
        });
    }

    public async updateStatuses(states: IStatusEntity[]): Promise<void> {
        return Logger.enterAsync<void>("DataModel.updateStatuses", async () => {
            this.api.storage.batchEntities(DataModel.StatusTableName, states, (batch, entry) => {
                batch.insertOrReplaceEntity(entry.toEntity("*"));
            });
        });
    }

    public async deleteStatuses(states: IStatusEntity[]): Promise<void> {
        return Logger.enterAsync<void>("DataModel.deleteStatuses", async () => {
            this.api.storage.batchEntities(DataModel.StatusTableName, states, (batch, entry) => {
                batch.deleteEntity(entry.toEntity());
            });
        });
    }

    public async upsertStatus(status: IStatusEntity): Promise<void> {
        return Logger.enterAsync<void>("DataModel.upsertStatus", async () => {
            const rowKey: string = StatusEntity.generateRowKey(status.id, status.type, status.tag);
            await this.api.storage.upsertEntity(
                DataModel.StatusTableName, DataModel.StatusEntitiesPK, rowKey, () => {
                    return new StatusEntity(
                        status.id, status.type, status.tag,
                        status.category, status.changedWhen,
                        status.status, status.data).toEntity();
                });
        });
    }

    public async fetchStatusMap(): Promise<IHashMap> {
        return Logger.enterAsync<IHashMap>("DataModel.fetchStatusMap", async () => {
            // fetch all current entries
            const entities = await this.readStatuses();
            // map them accordinly for easier traversal
            return Promise.resolve(this.mapStatusEntities(entities));
        });
    }

    private async initialize(): Promise<void> {
        // see if ready
        const isReady = await this.isReady();
        // check if ready or not so we can init all
        if (!isReady) {
            // create tables
            await this.api.storage.createTable(DataModel.ConfigurationTableName);
            await this.api.storage.createTable(DataModel.StateTableName);
            await this.api.storage.createTable(DataModel.StatusTableName);
            // mark as ready
            await this.markReady();
        }
    }

    private async markReady(): Promise<void> {
        return Logger.enterAsync<void>("DataModel.markReady", async () => {
            return this.markReadyState("data-model-system-state");
        });
    }

    private mapStateEntities(entities: IStateEntity[]): IHashMap {
        return Logger.enter<IHashMap>("DataModel.mapStateEntities", () => {
            const map = new HashMap();
            for (const entity of entities) {
                const resource = new Resource(entity.id);
                if (map.has(resource.subscriptionId) === false) {
                    map.set(resource.subscriptionId, new HashMap());
                }
                if (map.get(resource.subscriptionId).has(resource.resourceGroup) === false) {
                    map.get(resource.subscriptionId).set(resource.resourceGroup, new HashMap());
                }
                if (map.get(resource.subscriptionId).get(resource.resourceGroup).has(resource.name) === false) {
                    map.get(resource.subscriptionId).get(resource.resourceGroup).set(resource.name, new HashMap());
                }
                if (map.get(resource.subscriptionId).get(resource.resourceGroup).get(resource.name)
                    .has(entity.tag) === false) {
                    map.get(resource.subscriptionId).get(resource.resourceGroup).get(resource.name)
                        .set(entity.tag, entity);
                }
            }
            return map;
        });
    }

    private mapStatusEntities(entities: IStatusEntity[]): IHashMap {
        return Logger.enter<IHashMap>("DataModel.mapStatusEntities", () => {
            const map = new HashMap();
            for (const entity of entities) {
                const resource = new Resource(entity.id);
                if (map.has(resource.subscriptionId) === false) {
                    map.set(resource.subscriptionId, new HashMap());
                }
                if (map.get(resource.subscriptionId).has(resource.resourceGroup) === false) {
                    map.get(resource.subscriptionId).set(resource.resourceGroup, new HashMap());
                }
                if (map.get(resource.subscriptionId).get(resource.resourceGroup).has(resource.name) === false) {
                    map.get(resource.subscriptionId).get(resource.resourceGroup).set(resource.name, new HashMap());
                }
                if (map.get(resource.subscriptionId).get(resource.resourceGroup).get(resource.name)
                    .has(entity.tag) === false) {
                    map.get(resource.subscriptionId).get(resource.resourceGroup).get(resource.name)
                        .set(entity.tag, entity);
                }
            }
            return map;
        });
    }
}

// export
export { DataModel };
