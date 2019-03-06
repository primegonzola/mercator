/* tslint:disable:max-classes-per-file */
import * as restler from "restler";
import {
    IApiClient,
    IComputeService,
    IStorageService,
    IVirtualMachineScaleSetService,
} from "./typings";

import { ComputeManagementClient } from "azure-arm-compute";
import { MonitorManagementClient } from "azure-arm-monitor";
import * as azureStorage from "azure-storage";
import { Logger } from "./logger";
import { Resource } from "./resource";

class StorageAccountInfo {
    private storageAccountName: string;
    private storageAccountKey: string;
    constructor(name: string, key: string) {
        this.storageAccountName = name;
        this.storageAccountKey = key;
    }
    get name() { return this.storageAccountName; }
    get key() { return this.storageAccountKey; }
}

class StorageService implements IStorageService {
    private storageAccountInfo: StorageAccountInfo;
    constructor(storageAccountInfo: StorageAccountInfo) {
        Logger.enter("StorageService.constructor", () => {
            this.storageAccountInfo = storageAccountInfo;
        });
    }
    public createTableQuery(): any {
        return Logger.enter<any>("StorageService.createTableQuery", () => {
            return new azureStorage.TableQuery();
        });
    }
    public createGenerator(): any {
        return Logger.enter<any>("StorageService.createGenerator", () => {
            return azureStorage.TableUtilities.entityGenerator;
        });
    }
    public createBlobService(): any {
        return Logger.enter<any>("StorageService.createBlobService", () => {
            return azureStorage.createBlobService(
                this.storageAccountInfo.name, this.storageAccountInfo.key);
        });
    }
    public createTableService(): any {
        return Logger.enter<any>("StorageService.createTableService", () => {
            return azureStorage.createTableService(
                this.storageAccountInfo.name, this.storageAccountInfo.key);
        });
    }
    public createTableBatch(): any {
        return Logger.enter<any>("StorageService.createTableBatch", () => {
            return new azureStorage.TableBatch();
        });
    }
    public createTable(name: string): Promise<void> {
        return Logger.enter<Promise<void>>("StorageService.createTable", () => {
            return new Promise((resolve, reject) => {
                const ts = this.createTableService();
                ts.createTableIfNotExists(name, (error, result, response) => {
                    if (error) { return reject(error); }
                    return resolve();
                });
            });
        });
    }
    public doesTableExist(name: string): Promise<boolean> {
        return Logger.enter<Promise<boolean>>("StorageService.tableExist", () => {
            return new Promise((resolve, reject) => {
                const ts = this.createTableService();
                ts.doesTableExist(name, (error, result, response) => {
                    if (error) { return reject(error); }
                    return resolve(result.exists);
                });
            });
        });
    }
    public batchEntities(
        table: string, entities: any[], operation: (batch: any, entity: any) => any): Promise<any[]> {
        return Logger.enter<Promise<any[]>>("StorageService.batchEntities", () => {
            // max size defined here
            const maxSize: number = 100;
            // sanity check
            if (entities.length === 0) { return Promise.resolve([]); }
            // list of calls
            const calls: any[] = [];
            let offset: number = 0;
            const total: number = Math.floor(entities.length / maxSize);
            // loop over entities
            for (let j = 0; j < total; j++) {
                const batch = this.createTableBatch();
                for (let i = 0; i < maxSize; i++) {
                    operation(batch, entities[offset]);
                    offset++;
                }
                // schedule call
                calls.push(this.executeBatch(table, batch));
            }
            if (entities.length - offset > 0) {
                const batch = this.createTableBatch();
                for (let i = offset; i < entities.length; i++) {
                    operation(batch, entities[i]);
                }
                // schedule call
                calls.push(this.executeBatch(table, batch));
            }
            // execute
            return Promise.all(calls);
        });
    }
    public executeBatch(table: string, batch: any): Promise<void> {
        return Logger.enter<Promise<void>>("StorageService.executeBatch", () => {
            return new Promise((resolve, reject) => {
                const ts = this.createTableService();
                ts.executeBatch(table, batch, (error: Error, result: any, response: string) => {
                    if (error) { return reject(error); }
                    return resolve();
                });
            });
        });
    }
    public queryEntities(name: string, query: any, token: any): Promise<any[]> {
        return Logger.enter<Promise<any[]>>("StorageService.queryEntities", () => {
            return new Promise((resolve, reject) => {
                const ts = this.createTableService();
                ts.queryEntities(name, query, token, (error: Error, result: any, response: string) => {
                    if (error) { return reject(error); }
                    return resolve(result.entries);
                });
            });
        });
    }
    public getEntities(name: string, pk: string): Promise<any[]> {
        return Logger.enter<Promise<any[]>>("StorageService.getEntities", () => {
            const query = new azureStorage.TableQuery().where("PartitionKey eq ?", pk);
            return this.queryEntities(name, query, null).then((entries: any[]) => {
                return Promise.resolve(entries);
            });
        });
    }
    public getEntity(name: string, pk: string, rk: string): Promise<any> {
        return Logger.enter<Promise<any>>("StorageService.getEntity", () => {
            const query = new azureStorage.TableQuery().where("PartitionKey eq ? and RowKey eq ?", pk, rk);
            return this.queryEntities(name, query, null).then((entries) => {
                if (entries === undefined || entries === null || entries.length === 0) {
                    return Promise.resolve(null);
                }
                return Promise.resolve(entries[0]);
            });
        });
    }
    public retrieveEntity(name: string, pk: string, rk: string): Promise<any> {
        return Logger.enter<Promise<any>>("StorageService.retrieveEntity", () => {
            return new Promise((resolve, reject) => {
                const ts = this.createTableService();
                ts.retrieveEntity(name, pk, rk, (error: Error, result: any, response: string) => {
                    if (error) { return reject(error); }
                    return resolve(result);
                });
            });
        });
    }
    public updateEntity(name: string, entity: string): Promise<any> {
        return Logger.enter<Promise<any>>("StorageService.updateEntity", () => {
            return new Promise((resolve, reject) => {
                const ts = this.createTableService();
                ts.replaceEntity(name, entity, (error: Error, result: any, response: string) => {
                    if (error) { return reject(error); }
                    return resolve(result);
                });
            });
        });
    }
    public upsertEntity(name: string, pk: string, rk: string, handler: () => any): Promise<void> {
        return Logger.enter<Promise<void>>("StorageService.upsertEntity", () => {
            return new Promise((resolve, reject) => {
                const data = handler() || null;
                if (data === null) { return resolve(null); }
                const generator = azureStorage.TableUtilities.entityGenerator;
                data.PartitionKey = generator.String(pk);
                data.RowKey = generator.String(rk);
                const ts = this.createTableService();
                ts.insertOrReplaceEntity(name, data, (error: Error, result: any, response: string) => {
                    if (error) { return reject(error); }
                    return resolve(result);
                });
            });
        });
    }
    public deleteEntity(name: string, pk: string, rk: string): Promise<void> {
        return Logger.enter<Promise<void>>("StorageService.deleteEntity", () => {
            return new Promise((resolve, reject) => {
                const ts = this.createTableService();
                this.retrieveEntity(name, pk, rk).then((entity) => {
                    ts.deleteEntity(name, entity, (error, result, response) => {
                        if (error) { return reject(error); }
                        return resolve();
                    });
                });
            });
        });
    }
    public writeText(container: string, path: string, text: string): Promise<void> {
        return Logger.enter<Promise<void>>("StorageService.writeText", () => {
            return new Promise((resolve, reject) => {
                const bs = this.createBlobService();
                bs.createContainerIfNotExists(container, (error, result, response) => {
                    if (error) { return reject(error); }
                    bs.createBlockBlobFromText(container, path, text, (err, res, resp) => {
                        if (err) { return reject(err); }
                        return resolve();
                    });
                });
            });
        });
    }
}

class ComputeService implements IComputeService {
    public virtualMachineScaleSets: IVirtualMachineScaleSetService;
    private subscriptionId: string;
    private credentials: any;

    constructor(credentials: any, subscriptionId: string) {
        Logger.enter("ComputeService.constructor", () => {
            this.credentials = credentials;
            this.subscriptionId = subscriptionId;
            this.virtualMachineScaleSets = new VirtualMachineScaleSetService(this.credentials, this.subscriptionId);
        });
    }
}

class VirtualMachineScaleSetService implements IVirtualMachineScaleSetService {
    private subscriptionId: string;
    private credentials: any;
    private computeClient: ComputeManagementClient;
    private monitorClient: MonitorManagementClient;
    constructor(credentials: any, subscriptionId: string) {
        Logger.enter("VirtualMachineScaleSetService.constructor", () => {
            this.credentials = credentials;
            this.subscriptionId = subscriptionId;
            this.computeClient = new ComputeManagementClient(this.credentials, this.subscriptionId);
            this.monitorClient = new MonitorManagementClient(this.credentials, this.subscriptionId);
        });
    }

    public async get(resourceGroup: string, name: string): Promise<any> {
        return Logger.enterAsync<any>("VirtualMachineScaleSetService.get", async () => {
            return await this.computeClient.virtualMachineScaleSets.get(resourceGroup, name);
        });
    }

    public async update(resourceGroup: string, name: string, data: any): Promise<any> {
        return Logger.enterAsync<any>("VirtualMachineScaleSetService.get", async () => {
            return await this.computeClient.virtualMachineScaleSets.createOrUpdate(resourceGroup, name, data);
        });
    }

    public async getAutoscaleSettings(resourceGroup: string, name: string): Promise<any> {
        return Logger.enterAsync<any>("VirtualMachineScaleSetService.getAutoscaleSettings", async () => {
            return await this.monitorClient.autoscaleSettings.get(resourceGroup, name);
        });
    }

    public async updateAutoscaleSettings(resourceGroup: string, name: string, data: any): Promise<any> {
        return Logger.enterAsync<any>("VirtualMachineScaleSetService.updateAutoscaleSettings", async () => {
            return await this.monitorClient.autoscaleSettings.createOrUpdate(resourceGroup, name, data);
        });
    }

    public async listVirtualMachines(resourceGroup: string, virtualMachineScaleSet: string): Promise<any[]> {
        return Logger.enterAsync<any[]>("VirtualMachineScaleSetService.listVirtualMachines", async () => {
            return await this.computeClient.virtualMachineScaleSetVMs.list(resourceGroup, virtualMachineScaleSet);
        });
    }

    public async deleteVirtualMachines(
        resourceGroup: string, virtualMachineScaleSet: string, ids: string[]): Promise<void> {
        return Logger.enterAsync("VirtualMachineScaleSetService.deleteVirtualMachines", async () => {
            await this.computeClient.virtualMachineScaleSets.deleteInstances(
                resourceGroup, virtualMachineScaleSet, ids);
        });
    }

    public listVirtualMachineNetworkInterfaces(resourceGroup: string, virtualMachineScaleSet: string): Promise<any[]> {
        return Logger.enter<Promise<any[]>>("VirtualMachineScaleSetService.listVirtualMachineNetworkInterfaces", () => {
            return new Promise((resolve, reject) => {
                this.credentials.getToken((error: Error, token: any) => {
                    if (error) { return reject(error); }
                    // set api version
                    const apiVersion = "2017-03-30";
                    // Construct uri
                    let uri = "https://management.azure.com" +
                        "/subscriptions/{subscriptionId}" +
                        "/resourceGroups/{resourceGroup}" +
                        "/providers/Microsoft.Compute" +
                        "/virtualMachineScaleSets/{virtualMachineScaleSet}/networkInterfaces";
                    // replace key parts
                    uri = uri.replace("{subscriptionId}", encodeURIComponent(this.subscriptionId));
                    uri = uri.replace("{resourceGroup}", encodeURIComponent(resourceGroup));
                    uri = uri.replace("{virtualMachineScaleSet}", encodeURIComponent(virtualMachineScaleSet));
                    // check query parameters
                    const queryParameters = ["api-version=" + encodeURIComponent(apiVersion)];
                    // check if anything to add
                    if (queryParameters.length > 0) { uri += "?" + queryParameters.join("&"); }
                    // do the request
                    restler.get(uri, { accessToken: token.accessToken })
                        .on("success", (result, response) => {
                            return resolve(result.value);
                        })
                        .on("error", (result, response) => {
                            return reject(new Error(response));
                        })
                        .on("fail", (result, response) => {
                            return reject(new Error(response));
                        });
                });
            });
        });
    }

    public findVirtualMachineNetworkInterface(nics: any[], vm: any): any {
        return Logger.enter<any>("VirtualMachineScaleSetService.findVirtualMachineNetworkInterface", () => {
            if (vm !== undefined && vm !== null) {
                for (const nic of nics) {
                    if (nic === undefined || nic === null) {
                        continue;
                    }
                    if (nic.properties === undefined || nic.properties === null) {
                        continue;
                    }
                    if (nic.properties.virtualMachine === undefined || nic.properties.virtualMachine === null) {
                        continue;
                    }
                    if (nic.properties.virtualMachine.id === undefined || nic.properties.virtualMachine.id === null) {
                        continue;
                    }
                    if (nic.properties.virtualMachine.id.toLowerCase() === vm.id.toLowerCase()) {
                        return nic;
                    }
                }
            }
            return null;
        });
    }
}

class ApiClient implements IApiClient {
    public static generator(): any {
        return Logger.enter<any>("ApiClient.generator", () => {
            return azureStorage.TableUtilities.entityGenerator;
        });
    }

    public static async createInstance(
        credentials: any, subscriptionId: string,
        storageAccountId: string, storageAccountKey: string): Promise<IApiClient> {
        return Logger.enterAsync<IApiClient>("ApiClient.createInstance", async () => {
            // return client
            return new ApiClient(credentials, subscriptionId, new StorageAccountInfo(
                new Resource(storageAccountId).name, storageAccountKey));
        });
    }

    public compute: IComputeService;
    public storage: IStorageService;
    private credentials: any;
    private subscriptionId: string;
    constructor(
        credentials: any,
        subscriptionId: string, storageAccountInfo: StorageAccountInfo) {
        Logger.enter("ApiClient.constructor", () => {
            this.credentials = credentials;
            this.subscriptionId = subscriptionId;
            this.storage = new StorageService(storageAccountInfo);
            this.compute = new ComputeService(this.credentials, this.subscriptionId);
        });
    }
}

// export
export { ApiClient };
