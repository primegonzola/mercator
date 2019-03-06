/* tslint:disable:max-classes-per-file */
import { IContext } from "./functions";

export interface IEnvironment {
    name: string;
    api: IApiClient;
    logger: ILogger;
    data: IDataModel;
    application: IApplicationModel;
    credentials: any;
    settings: Settings;
}

export declare class ApigeeController {
    constructor(credentials: string);
    public setTargetPercentage(value: number): Promise<void>;
    public getTargetPercentage(): Promise<number>;
    public clearCache(): Promise<void>;
}

export declare class Environment implements IEnvironment {
    public static isEnabled(): boolean;
    public static createInstance(context: IContext);
    public name: string;
    public api: IApiClient;
    public logger: ILogger;
    public data: IDataModel;
    public application: IApplicationModel;
    public credentials: any;
    public settings: Settings;
}

export declare class Settings {
    public static isEnabled: boolean;
    public static get(credentials?: any): Promise<Settings>;
    public resourceGroup: string;
    public statusTopicId: string;
    public subscriptionId: string;
    public storageAccountId: string;
    public keyVaultUri: string;
    public storageAccountKey: string;
    public webHookUri: string;
    public applicationInsightsKey: string;
    constructor(
        subscriptionId: string,
        resourceGroup: string,
        keyVaultUri: string,
        storageAccountId: string,
        storageAccountKey: string,
        statusTopicId: string,
        webHookUri: string,
        applicationInsightsKey: string,
    );
}

export interface IRowEntity {
    partitionKey: string;
    rowKey: string;
    metadata?: object;
}

export declare class RowEntity implements IRowEntity {
    public partitionKey: string;
    public rowKey: string;
    public metadata?: object;
    constructor(partitionKey: string, rowKey: string, metadata?: object);
}

export interface IStateEntity extends IRowEntity {
    id: string;
    type: string;
    createdWhen: Date;
    tag: string;
    state: string;
}

declare class StateEntity extends RowEntity implements IStateEntity {
    public id: string;
    public type: string;
    public createdWhen: Date;
    public tag: string;
    public state: string;
}

export interface IStatusEntity extends IRowEntity {
    id: string;
    category: string;
    data: any;
    type: string;
    tag: string;
    changedWhen: Date;
    status: string;
    timestamp: Date;
}

declare class StatusEntity extends RowEntity implements IStatusEntity {
    public id: string;
    public category: string;
    public data: any;
    public type: string;
    public tag: string;
    public changedWhen: Date;
    public status: string;
    public timestamp: Date;
}

export interface ILoggerOptions {
    category: string;
    filter: number;
}

export type LoggerOptions = {
    category?: string;
    custom?: any;
    filter?: any;
    applicationInsightsKey?: string;
};

export interface ILogger {
    trace(msg: string): void;
    info(msg: string): void;
    warn(msg: string, error?: Error): void;
    error(msg: string, error?: Error): void;
}

export declare class Logger implements ILogger {
    public static enter<T>(caller: string, fn: () => T): T;
    public static enterAsync<T>(caller: string, fn: () => Promise<T>): Promise<T>;
    public static createInstance(context: IContext, options?: LoggerOptions): Promise<ILogger>;
    public static log(data: any);
    public trace(msg: string): void;
    public info(msg: string): void;
    public warn(msg: string, error?: Error): void;
    public error(msg: string, error?: Error): void;
}

export interface IResource {
    subscriptionId: string;
    resourceGroup: string;
    provider: string;
    type: string;
    name: string;
    uri: string;
}

export declare class Resource implements IResource {
    public subscriptionId: string;
    public resourceGroup: string;
    public provider: string;
    public type: string;
    public name: string;
    public uri: string;
    constructor(resourceUri: string);
}

export interface IHashMap {
    has(key: any): boolean;
    get(key: any): any;
    set(key: any, value: any): void;
    remove(key: any): void;
    size(): number;
    clear(): void;
    each(cb: (key: any, value: any) => void);
}

export declare class HashMap implements IHashMap {
    public has(key: any): boolean;
    public get(key: any): any;
    public set(key: any, value: any): void;
    public remove(key: any): void;
    public size(): number;
    public clear(): void;
    public each(cb: (key: any, value: any) => void);
}

export declare class Utils {
    public static isDebug(): boolean;
    public static findObject(owners: any[], name: string, value: any): any;
    public static getVariable(name: string, def: any): string;
    public static createTableGenerator(): any;
    public static hostNameToInstanceId(name): number;
    public static instanceToHostName(prefix: string, id: number): string;
}

export interface IStorageService {
    createGenerator(): any;
    createTableQuery(): any;
    createBlobService(): any;
    createTableService(): any;
    createTableBatch(): any;
    createTable(name): Promise<void>;
    doesTableExist(name): Promise<boolean>;
    batchEntities(
        table: string, entities: any[], operation: (batch: any, entity: any) => any): Promise<any[]>;
    executeBatch(table: string, batch: any): Promise<void>;
    queryEntities(name: string, query: any, token: any): Promise<any[]>;
    getEntities(name: string, pk: string): Promise<any[]>;
    getEntity(name: string, pk: string, rk: string): Promise<any>;
    retrieveEntity(name: string, pk: string, rk: string): Promise<any>;
    updateEntity(name: string, entity: any): Promise<any>;
    upsertEntity(name: string, pk: string, rk: string, handler: () => any): Promise<any>;
    deleteEntity(name: string, pk: string, rk: string): Promise<void>;
    writeText(container: string, path: string, text: string): Promise<void>;
}

export interface IComputeService {
    virtualMachineScaleSets: IVirtualMachineScaleSetService;
}

export interface IVirtualMachineScaleSetService {
    getAutoscaleSettings(resourceGroup: string, name: string): Promise<any>;
    updateAutoscaleSettings(resourceGroup: string, name: string, data: any): Promise<any>;
    get(resourceGroup: string, name: string): Promise<any>;
    update(resourceGroup: string, name: string, data: any): Promise<any>;
    findVirtualMachineNetworkInterface(nics: any[], vm: any): any;
    listVirtualMachines(resourceGroup: string, virtualMachineScaleSet: string): Promise<any[]>;
    listVirtualMachineNetworkInterfaces(resourceGroup: string, virtualMachineScaleSet: string): Promise<any[]>;
    deleteVirtualMachines(resourceGroup: string, virtualMachineScaleSet: string, ids: string[]): Promise<void>;
}

export interface IApiClient {
    storage: IStorageService;
    compute: IComputeService;
}

export declare class ApiClient {
    public static createInstance(
        credentials: any, subscriptionId: string,
        storageAccountId: string, storageAccountKey: string): Promise<IApiClient>;
}

export type StatusEvent = {
    topic: string;
    subject: string;
    eventType: string;
    data: {
        category: string,
        name: string,
        type: string,
        status: string,
        data: any,
    };
};

export interface IStatusTarget {
    name: string;
    type: string;
    resources: string[];
    grace: number;
    minimum: number;
    expiration: number;
    unhealthy: string;
}

export declare class StatusTarget {
    public static targets: IStatusTarget[];
    public static getByResourceId(id: string): IStatusTarget;
    public name: string;
    public type: string;
    public resources: string[];
    public grace: number;
    public minimum: number;
    public expiration: number;
    public unhealthy: string;
    constructor(
        name: string, type: string,
        resources: string[], unhealthy: string,
        expiration: number, grace: number, minimum: number)
}

export type ApplicationModelOptions = {
    topicId: string;
    subscriptionId: string;
    resourceGroup: string;
    storageAccountId: string;
};

export interface IApplicationModel {
    environment: IEnvironment;
    state(): Promise<void>;
    status(): Promise<void>;
    event(event: StatusEvent): Promise<void>;
}

export declare class ApplicationModel implements IApplicationModel {
    public static createInstance(
        environment: IEnvironment, options?: ApplicationModelOptions): Promise<IApplicationModel>;
    public environment: IEnvironment;
    public state(): Promise<void>;
    public status(): Promise<void>;
    public event(event: StatusEvent): Promise<void>;
}

export interface IDataModel {
    isReady(): Promise<boolean>;
    isReadyState(name: string): Promise<boolean>;
    markReadyState(name: string): Promise<void>;
    fetchStateMap(): Promise<IHashMap>;
    upsertState(state: IStateEntity): Promise<void>;
    queryStatesById(id: string): Promise<IStateEntity[]>;
    readState(id: string, type: string, tag: string): Promise<IStateEntity>;
    readStates(): Promise<IStateEntity[]>;
    createStates(states: IStateEntity[]): Promise<void>;
    updateStates(states: IStateEntity[]): Promise<void>;
    deleteStates(states: IStateEntity[]): Promise<void>;
    queryStatusesById(id: string): Promise<IStatusEntity[]>;
    readStatus(id: string, type: string, tag: string): Promise<IStatusEntity>;
    readStatuses(): Promise<IStatusEntity[]>;
    createStatuses(states: IStatusEntity[]): Promise<void>;
    updateStatuses(states: IStatusEntity[]): Promise<void>;
    deleteStatuses(states: IStatusEntity[]): Promise<void>;
    upsertStatus(status: IStatusEntity): Promise<void>;
    fetchStatusMap(): Promise<IHashMap>;
}

export declare class DataModel implements IDataModel {
    public static createInstance(api: IApiClient);
    public isReady(): Promise<boolean>;
    public isReadyState(name: string): Promise<boolean>;
    public markReadyState(name: string): Promise<void>;
    public fetchStateMap(): Promise<IHashMap>;
    public upsertState(state: IStateEntity): Promise<void>;
    public queryStatesById(id: string): Promise<IStateEntity[]>;
    public readState(id: string, type: string, tag: string): Promise<IStateEntity>;
    public readStates(): Promise<IStateEntity[]>;
    public createStates(states: IStateEntity[]): Promise<void>;
    public updateStates(states: IStateEntity[]): Promise<void>;
    public deleteStates(states: IStateEntity[]): Promise<void>;
    public queryStatusesById(id: string): Promise<IStatusEntity[]>;
    public readStatus(id: string, type: string, tag: string): Promise<IStatusEntity>;
    public readStatuses(): Promise<IStatusEntity[]>;
    public createStatuses(states: IStatusEntity[]): Promise<void>;
    public updateStatuses(states: IStatusEntity[]): Promise<void>;
    public deleteStatuses(states: IStatusEntity[]): Promise<void>;
    public upsertStatus(status: IStatusEntity): Promise<void>;
    public fetchStatusMap(): Promise<IHashMap>;
}
